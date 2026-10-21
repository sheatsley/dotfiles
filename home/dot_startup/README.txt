Put startup scripts (.ps1, .bat, .cmd, .exe, .vbs) in this folder inside the repo (home/dot_startup/).
chezmoi copies them to ~\.startup\, and the startup shortcuts step creates a shortcut for each one in shell:startup.
This README is ignored by that step, since .txt is not a runnable type.
