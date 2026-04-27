cask "hellowork" do
  version :latest
  sha256 :no_check

  url "https://github.com/a2rk/hello-work/releases/latest/download/HelloWork.dmg"
  name "Hello work"
  desc "Schedule-based app blocking, focus mode, menubar minimalism for developers"
  homepage "https://github.com/a2rk/hello-work"

  app "Hello work.app"

  # Cleanup: при `brew uninstall --zap` убираем всё что приложение положило.
  zap trash: [
    "~/Library/Application Support/HelloWork",
    "~/Library/Preferences/dev.helloworkapp.macos.plist",
    "~/Library/Preferences/dev.helloworkapp.macos.engine.plist",
  ]
end
