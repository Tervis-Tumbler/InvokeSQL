# InvokeSQL

## Installation

Install for the current user by transferring the files in this repository to `USERPROFILE\Documents\WindowsPowerShell\Modules`.  

To find `USERPROFILE`, run in Powershell:

```powershell
> $env:USERPROFILE
```

However, this may not give you the full story if you have OneDrive set up on your machine. To check the actual module path, run:

```powershell
> $env:PSModulePath -split ';'
```

and note which path is under your user name. Navigate to that location.  

To clone the files from GitHub:

```powershell
> git clone https://github.com/Tervis-Tumbler/InvokeSQL.git
```
