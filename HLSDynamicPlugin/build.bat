@echo off

pushd %~dp0

@call ..\properties.bat

@call "%flex_bin%\mxmlc.bat" -o "..\%build_dir%\HLSDynamicPlugin.swf" ^
	-debug=%debug% ^
	-swf-version=11 ^
	-target-player=%target_player% ^
	-default-size=640,360 ^
	-default-background-color=0 ^
	-static-link-runtime-shared-libraries=true ^
	-l "%flex_sdk%\frameworks\libs" "%flex_sdk%\frameworks\locale\{locale}" ^
	-l ..\%build_dir% ^
	-define CONFIG::FLASH_10_1 %FLASH_10_1% ^
	-define CONFIG::LOGGING %logging% ^
	-- src\HLSDynamicPlugin.as

popd