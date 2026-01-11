import os.log

enum Log {
    static let app = Logger(subsystem: AppConstants.bundleId, category: "app")
    static let gesture = Logger(subsystem: AppConstants.bundleId, category: "gesture")
    static let permissions = Logger(subsystem: AppConstants.bundleId, category: "permissions")
    static let navigation = Logger(subsystem: AppConstants.bundleId, category: "navigation")

    static func debug(_ logger: Logger, _ message: String) {
        #if DEBUG
        logger.debug("\(message, privacy: .public)")
        #endif
    }

    static func info(_ logger: Logger, _ message: String) {
        logger.info("\(message, privacy: .public)")
    }
}
