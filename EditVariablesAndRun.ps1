Import-Module $PSScriptRoot\CropFromAllSides.ps1 -Force

#EDIT these Variables and run this script:

#Edit this variable to set a directory as the the current working location:
#(E.g $working_location  = "C:\Users\User\MyVideos")
#This is optional but makes it possible to work without full file paths.
#($PSScriptRoot is the directory where this powershell script is located.)
$working_location = $PSScriptRoot

#Set file:
$input_file  = "foobar.mp4"
$output_file = "foobar_new.mp4"

#Set the number of pixels you want to cut from each side: 
$cut_top     = 50
$cut_bottom  = 75
$cut_left    = 100
$cut_right   = 150

#Set times for video cuts:
#HH:MM:SS.XXXX... or SS.XXXX... format, where .XXXX... is optional.
#Empty (= "") if you want to cut from the beginning or until the end.
$start_time  = ""     
$stop_time   = ""     

#Alter the list of paramters for your FFplay command:
#(-to parameter is supported by this script)
#(-autoscale is a custom parameter to fit the video on screen)
[Collections.Generic.List[object]]$ffplay_paras = @(
    '-i',        $input_file  
    '-ss',       $start_time
    '-to',       $stop_time
    '-autoscale',
    '-vf',      "crop=X"       #Must include "crop=X", multiple filters are allowed, e.g "crop=X, vflip"
    '-autoexit'
)

#Alter the list of paramters for your FFmpeg command:
[Collections.Generic.List[object]]$ffmpeg_paras = @(
    '-i',       $input_file  
    '-ss',      $start_time
    '-to',      $stop_time
    '-vf',      "crop=X"       #Must include "crop=X", multiple filters are allowed, e.g "crop=X, vflip"
    '-crf',     14
    '-preset',  "veryslow"
    '-y',
                $output_file
)

Import-Module $PSScriptRoot\Initialize.ps1 -Force