class CropFilter{
    
    hidden [int]$Top_Cut     = 0
    hidden [int]$Bottom_Cut  = 0
    hidden [int]$Left_Cut    = 0
    hidden [int]$Right_Cut   = 0

    hidden [string]$Crop_Filter


    CropFilter(
        [int]$top,
        [int]$bottom,
        [int]$left,
        [int]$right
    ){
        $this.Top_Cut      = if([string]::IsNullOrEmpty($top))   {0} else {$top}
        $this.Bottom_Cut   = if([string]::IsNullOrEmpty($bottom)){0} else {$bottom}
        $this.Left_Cut     = if([string]::IsNullOrEmpty($left))  {0} else {$left}
        $this.Right_Cut    = if([string]::IsNullOrEmpty($right)) {0} else {$right} 
    
        $this.Crop_Filter  = $this.CalculateCropFilter($this.Top_Cut, $this.Bottom_Cut, $this.Left_Cut, $this.Right_Cut)    
    }


    #This method creates a valid value for the -vf Crop Filter based on defined side cuts:
    [string] CalculateCropFilter([int]$top, [int]$bottom, [int]$left, [int]$right){
      
        $X = $left
        $Y = $top
        $W = "in_w" + "-" + ($X + $right)
        $H = "in_h" + "-" + ($Y + $bottom)
        $crop = "crop=" + $W + ":" + $H + ":" + $X + ":" + $Y

        return $crop
    }    


    #This method checks if a video file is compatible with the defined crop values of this CropFilter object:
    [void] CheckVideoCompatibility([string]$video_file)
    {
        $video_height = ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=s=x:p=0 $video_file
        $video_width  = ffprobe -v error -select_streams v:0 -show_entries stream=width  -of csv=s=x:p=0 $video_file

        if (($this.Top_Cut + $this.Bottom_Cut) -ge $video_height)
        {
        $over_height = $this.Top_Cut + $this.Bottom_Cut - $video_height
        throw [ArgumentOutOfRangeException] ("Top and Bottom values must be smaller than the Video Height:" `
                                            +"`n" + "The Video Height of " + $video_height + " pixels is exceeded by " + $over_height + " pixels.")        
        }

        if (($this.Left_Cut + $this.Right_Cut) -ge $video_width)
        {
        $over_width = $this.Left_Cut + $this.Right_Cut - $video_width
        throw [ArgumentOutOfRangeException] ("Left and Right values must be smaller than the Video Width:" `
                                             +"`n" + "The Video Width of " + $video_width  + " pixels is exceeded by " + $over_width  + " pixels.")  
        }
    }
    

    #This method prints the -vf parameter and the Crop Filter with its values:
    [void] PrintCropFilterParameter()
    {
        "-vf " + '"' + $this.Crop_Filter + '"' | Out-Host
    }
       
    
    #This method returns the Crop Filter:
    [string] GetCropFilter()
    {
        return $this.Crop_Filter
    }
}



class VideoCropper{    
    
    hidden [Collections.Generic.List[object]]$FF_Paras
    hidden [CropFilter]$Crop_Filter
    
    hidden [string]$Video_File
    
    hidden [int]$Start_Pos
    hidden [string]$Start_Value = $null
    hidden [int]$End_Pos
    hidden [string]$End_Value   = $null
    
    hidden [int]$Filter_Pos
    hidden [string]$Filter_Value   


    VideoCropper(
        [Collections.Generic.List[object]]$ff_paras,
        [CropFilter]$crop_filter     
    ){
        $this.FF_Paras     = $ff_paras
        $this.Crop_Filter  = $crop_filter
        
        $this.Video_File   = $this.FF_Paras[$this.FF_Paras.IndexOf('-i') + 1]
        $this.CheckFile($this.Video_File)
        $this.Crop_Filter.CheckVideoCompatibility($this.Video_File)

        $this.Start_Pos    = $this.FF_Paras.IndexOf('-ss')
        $this.Start_Value  = if($this.Start_Pos -ne -1) {$this.FF_Paras[$this.Start_Pos + 1]}
        $this.RemoveEmptyTime($this.Start_Pos, $this.Start_Value)
        $this.CheckTimeFormat("-ss", $this.Start_Value)        
        
        $this.End_Pos      = $this.FF_Paras.IndexOf('-to')
        $this.End_Value    = if($this.End_Pos -ne -1) {$this.FF_Paras[$this.End_Pos + 1]}
        $this.RemoveEmptyTime($this.End_Pos, $this.End_Value)
        $this.CheckTimeFormat("-to", $this.End_Value)

        $this.Filter_Pos   = $this.FF_Paras.IndexOf('-vf')
        $this.Filter_Value = $this.FF_Paras[$this.Filter_Pos + 1]
        $this.InsertVfCropFilter($this.Filter_Pos, $this.Filter_Value, $this.Crop_Filter)                
    }

    
    #This method checks if a file exists:
    hidden [void] CheckFile([string]$input)
    {
        $input = [IO.Path]::GetFullPath($input)
        
        if (-not([System.IO.File]::Exists($input))) 
        {
        throw [IO.FileNotFoundException] ("Input-File does not exist:" `
                                         +"`n" + $input)
        }
    }
        

    #This method removes the time parameter if its value is empty:
    hidden [void] RemoveEmptyTime([int]$time_pos, [string]$time_value)
    {
        if ([string]::IsNullOrEmpty($time_value))
        {
            $this.FF_Paras.RemoveAt($time_pos + 1)
            $this.FF_Paras.RemoveAt($time_pos)                       
        }
    }
        
    
    #This method checks if the time parameter value has a correct time format:
    hidden [void] CheckTimeFormat([string]$time_para, [string]$time_value)
    {
        if (-not([string]::IsNullOrEmpty($time_value)))
        {
            $time_regex_one = '^\d{2,}:[0-5][0-9]:[0-5][0-9](\.\d+)?$'  #...HH:MM:SS.XXXXXX...
            $time_regex_two = '^\d+(\.\d+)?$'                           #...S.XXXXXX...

            if (-not(($time_value -match $time_regex_one) -or ($time_value -match $time_regex_two)))
            {
                 throw [FormatException] ("The parameter value for " + $time_para + " has a wrong format:" `
                                         +"`n" + $time_value)
            }
        }
    }


    #This method inserts the crop values into the -vf filter of the parameter list:
    hidden [void] InsertVfCropFilter([int]$vf_pos, [string]$vf_value, [CropFilter]$crop_obj)
    {
        if (-not($vf_value -match "crop=X"))
        {
            throw [FormatException] ("The -vf parameter value inside the parameter list must include `"crop=X`":" `
                                    +"`n" + $vf_value)
        }
        
        $crop_values                = $crop_obj.GetCropFilter()       
        $vf_value                   = $vf_value.Replace("crop=X", $crop_values)        
        $this.FF_Paras[$vf_pos + 1] = $vf_value
    }


    #This method prints the command line using a parameter list:
    hidden [void] PrintFFCommand([string]$ff_command, [Collections.Generic.List[object]]$ff_paras)
    {
        [char[]]$excl_chars     = ('-', '"', "'")        
                
        #All paramter values should be put in quotations:
        [string]$command_line = $ff_paras | ForEach {$fst = $_.ToString()[0] ; if($excl_chars.Contains($fst)) {$_} else {'"'+ $_ +'"'}}

        "`n" + $ff_command + " " + $command_line  + "`n" | Out-Host
    }
}



class FFplayVideoCropper : VideoCropper {

    FFPlayVideoCropper(
        [Collections.Generic.List[object]]$ffplay_paras,
        [CropFilter]$crop_filter       
    ): base(
             $ffplay_paras,
             $crop_filter            
    ){       
        #FFplay only supports the -t duration parameter.
        if ($this.FF_Paras.Contains("-to"))
        {            
            
            $this.InsertDuration($this.Start_Value, $this.End_Pos, $this.End_Value)            
        }       
        
        #Translate custom -autoscale parameter into valid ffplay arguments.
        if ($this.FF_Paras.Contains("-autoscale"))
        {           
            $this.ScaleVideo()    
        }          
    }


    #This method translates the -to parameter into a -t paramter and edits the parameter list accordingly:    
    hidden [void] InsertDuration([string]$ss_value, [int]$to_pos, [string]$to_value)
    {        
        $time_regex = '^\d{2,}:[0-5][0-9]:[0-5][0-9](\.\d+)?$' #...HH:MM:SS.XXXXXX...

        if (-not([string]::IsNullOrEmpty($ss_value)))
        {
            $ss_value = if($ss_value -match $time_regex) {$this.TimestampToSeconds($ss_value)}
            $to_value = if($to_value -match $time_regex) {$this.TimestampToSeconds($to_value)}
            $duration = $to_value - $ss_value                                            
        }
        else
        {
            $duration = $to_value
        }    

        $this.FF_Paras[$to_pos]     = "-t"
        $this.FF_Paras[$to_pos + 1] = $duration    
    } 
        

    #This method parses a HH:MM:SS.XXX timestamp (where HH can be larger than 23) into seconds.
    hidden [Double] TimestampToSeconds([string] $timestamp)
    {
        [Double[]]$split_timestamp = $timestamp.Split(':')
        
        return $split_timestamp[0] * 3600 + $split_timestamp[1] * 60 + $split_timestamp[2]    
    }


    #This method scales down the FFplay video player to fit on the screen: 
    hidden [void] ScaleVideo()
    {       
        $autoscale_pos = $this.FF_Paras.IndexOf('-autoscale')               
        
        #-x or -y parameters overwrite the -autoscale parameter:
        if ($this.FF_Paras.Contains("-x") -or $this.FF_Paras.Contains("-y"))
        {
            $this.FF_Paras.RemoveAt($autoscale_pos)
            return
        }
        
        $width_limit  = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Width  * 0.9
        $height_limit = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Height * 0.9
                
        $video_width  = ffprobe -v error -select_streams v:0 -show_entries stream=width  -of csv=s=x:p=0 $this.Video_File
        $video_height = ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=s=x:p=0 $this.Video_File 
                 
        
        #Scale down the dimension that is further out of bounds: 
        if($video_width -gt $width_limit -or $video_height -gt $height_limit)
        {
            $width_ratio  = $video_width  / $width_limit
            $height_ratio = $video_height / $height_limit

            if($width_ratio -gt $height_ratio)
            {
                $this.FF_Paras[$autoscale_pos] = "-x"
                $this.FF_Paras.Insert($autoscale_pos + 1, $width_limit)
            }
            else
            {
                $this.FF_Paras[$autoscale_pos] = "-y"
                $this.FF_Paras.Insert($autoscale_pos + 1, $height_limit)
            }
        }
        else
        {
            $this.FF_Paras.RemoveAt($autoscale_pos)
        }
    }


    #This method plays a video using FFplay with the parameters in $FF_Paras:
    [void] ShowCroppedDemo()
    {
        $this.PrintFFCommand("ffplay", $this.FF_Paras)
        
        ffplay $this.FF_Paras 2>&1 | % {"$_"} | Out-Host
    }
}



class FFmpegVideoCropper : VideoCropper {

    FFmpegVideoCropper(
        [Collections.Generic.List[object]]$ffmpeg_paras,
        [CropFilter]$crop_filter       
    ): base(
             $ffmpeg_paras,
             $crop_filter          
    ){
    }

    #This method plays a video using FFplay with the parameters in $FF_Paras:
    [void] CreateCroppedVideo()
    {
        $this.PrintFFCommand("ffmpeg", $this.FF_Paras)
        
        ffmpeg $this.FF_Paras 2>&1 | % {"$_"} | Out-Host
    }   
}