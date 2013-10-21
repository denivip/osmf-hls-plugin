@echo off

pushd %~dp0

@call ..\properties.bat

@call "%flex_bin%\compc.bat" -o "..\%build_dir%\HLSPlugin.swc" ^
	-debug=%debug% ^
	-swf-version=11 ^
	-target-player=%target_player% ^
	-sp "src" ^
	-is "src" ^
	-define CONFIG::FLASH_10_1 %FLASH_10_1% ^
	-define CONFIG::LOGGING %logging%

popd