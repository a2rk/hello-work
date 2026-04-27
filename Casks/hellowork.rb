cask "hellowork" do
  version :latest
  sha256 :no_check

  url "https://github.com/a2rk/hello-work/releases/latest/download/HelloWork.dmg"
  name "HelloWork"
  desc "Schedule-based app blocking, focus mode, menubar minimalism for developers"
  homepage "https://github.com/a2rk/hello-work"

  app "HWInstaller.app"

  # Сносим старый бандл с пробелом в имени (до 0.9.19), если остался от прошлых версий.
  preflight do
    legacy = "/Applications/Hello work.app"
    if File.directory?(legacy)
      system_command "/bin/rm", args: ["-rf", legacy], sudo: false
    end
  end

  # Cleanup: при `brew uninstall --zap` убираем всё что приложение положило.
  zap trash: [
    "~/Library/Application Support/HelloWork",
    "~/Library/Preferences/dev.helloworkapp.macos.plist",
    "~/Library/Preferences/dev.helloworkapp.macos.engine.plist",
  ]
end
