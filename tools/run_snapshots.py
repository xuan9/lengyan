import os
import subprocess
import shutil
import time

workspace = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cache_dir = os.path.expanduser("~/Library/Caches/tools.fastlane")
screenshots_cache_dir = os.path.join(cache_dir, "screenshots")

devices = [
    "iPhone 13 Pro Max",
    "iPad Pro 13-inch (M5)"
]

languages = {
    "zh-Hans": "zh_CN",
    "zh-Hant": "zh_TW"
}

def run_cmd(cmd, cwd=None):
    print(f"Running: {cmd}")
    res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, cwd=cwd)
    print(res.stdout)
    if res.returncode != 0:
        print(f"Error: Command failed with exit code {res.returncode}")
    return res.returncode == 0

def main():
    # Make sure cache directories exist
    os.makedirs(screenshots_cache_dir, exist_ok=True)
    
    for lang, locale in languages.items():
        print(f"\n=================== Language: {lang} ===================")
        # Write language and locale info
        with open(os.path.join(cache_dir, "language.txt"), "w") as f:
            f.write(lang)
        with open(os.path.join(cache_dir, "locale.txt"), "w") as f:
            f.write(locale)
        with open(os.path.join(cache_dir, "snapshot-launch_arguments.txt"), "w") as f:
            f.write("")

        dest_dir = os.path.join(workspace, "fastlane", "screenshots", lang)
        os.makedirs(dest_dir, exist_ok=True)

        for device in devices:
            print(f"\nRunning tests on device: {device}...")
            
            # Clear screenshots cache directory
            if os.path.exists(screenshots_cache_dir):
                for f in os.listdir(screenshots_cache_dir):
                    fp = os.path.join(screenshots_cache_dir, f)
                    if os.path.isfile(fp):
                        os.remove(fp)

            # Boot simulator
            run_cmd(f"xcrun simctl boot '{device}'")
            
            # Run xcodebuild test
            cmd = (
                f"xcodebuild test -project lengyan.xcodeproj -scheme lengyan "
                f"-destination 'platform=iOS Simulator,name={device}' "
                f"-only-testing:lengyanUITests/SutraSnapshotTests/testAppStoreScreenshots"
            )
            success = run_cmd(cmd, cwd=workspace)
            
            # Copy generated screenshots
            if os.path.exists(screenshots_cache_dir):
                for file_name in os.listdir(screenshots_cache_dir):
                    if file_name.endswith(".png"):
                        src_file = os.path.join(screenshots_cache_dir, file_name)
                        dest_file = os.path.join(dest_dir, file_name)
                        shutil.copy2(src_file, dest_file)
                        print(f"Copied screenshot: {file_name} -> {dest_file}")
            
            # Shutdown simulator
            run_cmd(f"xcrun simctl shutdown '{device}'")

    print("\nRegenerating final overlay screenshots...")
    overlay_script = os.path.join(workspace, "tools", "overlay_screenshot_text.py")
    run_cmd(f"python3 {overlay_script}", cwd=workspace)
    print("Done!")

if __name__ == "__main__":
    main()
