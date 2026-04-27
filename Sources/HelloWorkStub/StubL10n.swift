import Foundation

enum StubLanguage {
    case en, ru, zh, system

    static func detected() -> StubLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("ru") { return .ru }
        if preferred.hasPrefix("zh") { return .zh }
        return .en
    }
}

enum StubL10n {
    static func subtitle(_ lang: StubLanguage) -> String {
        switch lang {
        case .ru: return "Готовлю основной модуль. Один раз и навсегда."
        case .zh: return "正在准备主模块。一次安装,从此忘记。"
        default:  return "Preparing the main module. One-time setup."
        }
    }

    static func preparing(_ lang: StubLanguage) -> String {
        switch lang {
        case .ru: return "ПОДГОТОВКА"
        case .zh: return "准备中"
        default:  return "PREPARING"
        }
    }

    static func checking(_ lang: StubLanguage) -> String {
        switch lang {
        case .ru: return "ИЩУ ПОСЛЕДНЮЮ ВЕРСИЮ"
        case .zh: return "查找最新版本"
        default:  return "CHECKING LATEST VERSION"
        }
    }

    static func downloading(_ lang: StubLanguage, percent: Int) -> String {
        switch lang {
        case .ru: return "СКАЧИВАЮ \(percent)%"
        case .zh: return "下载中 \(percent)%"
        default:  return "DOWNLOADING \(percent)%"
        }
    }

    static func mounting(_ lang: StubLanguage) -> String {
        switch lang {
        case .ru: return "РАСПАКОВЫВАЮ"
        case .zh: return "解包中"
        default:  return "UNPACKING"
        }
    }

    static func copying(_ lang: StubLanguage) -> String {
        switch lang {
        case .ru: return "УСТАНАВЛИВАЮ"
        case .zh: return "安装中"
        default:  return "INSTALLING"
        }
    }

    static func launching(_ lang: StubLanguage) -> String {
        switch lang {
        case .ru: return "ЗАПУСКАЮ"
        case .zh: return "启动中"
        default:  return "LAUNCHING"
        }
    }

    static func ready(_ lang: StubLanguage) -> String {
        switch lang {
        case .ru: return "ГОТОВО"
        case .zh: return "完成"
        default:  return "READY"
        }
    }

    static func errorTitle(_ lang: StubLanguage) -> String {
        switch lang {
        case .ru: return "Не получилось"
        case .zh: return "失败"
        default:  return "Something went wrong"
        }
    }
}
