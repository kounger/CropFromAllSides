#Set the current working location:
if (Test-Path -Path $working_location -PathType Container)
{
    #Change the current location for this PowerShell runspace:
    Set-Location $working_location

    #Change the current working directory for .NET:
    [System.IO.Directory]::SetCurrentDirectory($working_location)
} 
else 
{
    throw [IO.FileNotFoundException] ("Specified working location is not a directory or does not exist:" `
                                     +"`n" + $working_location) 
}


#Check if FFmpeg is installed on this system:
try
{
    ffmpeg -version | Out-Null
}
catch [System.Management.Automation.CommandNotFoundException]
{
    throw [System.Management.Automation.CommandNotFoundException] `
          ("FFmpeg is not installed on this system!" `          +"`nInstall FFmpeg for this script to function!")
}


Write-Output("`n" `
            +"#########################" +"`n" `
            +"CROP VIDEO FROM ALL SIDES" +"`n" `
            +"#########################" +"`n" `
            +"`n" `
            +"Choose one of the following options:" +"`n" `
            +"`n" `
            +"Enter `"1`" to display the crop filter parameter." +"`n" `
            +"Enter `"2`" to show the cropped video with FFplay." +"`n" `
            +"Enter `"3`" to encode the cropped video with FFmpeg." `
            +"`n")


$option = Read-Host -Prompt 'Enter a number'

switch ($option){
    #Option One:
    1 
    {
        [CropFilter]$crop_filter = [CropFilter]::new($cut_top, $cut_bottom, $cut_left, $cut_right)
        $crop_filter.PrintCropFilterParameter()
    }
    #Option Two:
    2 
    {
        [CropFilter]$crop_filter = [CropFilter]::new($cut_top, $cut_bottom, $cut_left, $cut_right)
        [FFplayVideoCropper]$ffplay_crop_tool = [FFplayVideoCropper]::new($ffplay_paras, $crop_filter)
        $ffplay_crop_tool.ShowCroppedDemo()
    }
    #Option three:
    3 
    {
        [CropFilter]$crop_filter = [CropFilter]::new($cut_top, $cut_bottom, $cut_left, $cut_right)
        [FFmpegVideoCropper]$ffmpeg_crop_tool = [FFmpegVideoCropper]::new($ffmpeg_paras,  $crop_filter)
        $ffmpeg_crop_tool.CreateCroppedVideo()
    }
}