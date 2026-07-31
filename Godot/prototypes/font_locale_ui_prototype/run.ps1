$prototypeRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonExe = "C:\Users\user\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
& $pythonExe -m http.server 4173 --directory $prototypeRoot
