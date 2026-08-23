import Flutter
import HealthKit
import UIKit
import UserNotifications
import home_widget

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let healthStore = HKHealthStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    if #available(iOS 17, *) {
      HomeWidgetBackgroundWorker.setPluginRegistrantCallback { registry in
        GeneratedPluginRegistrant.register(with: registry)
      }
    }
    GeneratedPluginRegistrant.register(with: self)
    configureHealthMoodChannel()
    configureNotificationSettingsChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureNotificationSettingsChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "florien/notification_settings",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "authorizationStatus":
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          let status: String
          switch settings.authorizationStatus {
          case .notDetermined:
            status = "notDetermined"
          case .denied:
            status = "denied"
          case .authorized, .provisional, .ephemeral:
            status = "authorized"
          @unknown default:
            status = "denied"
          }
          DispatchQueue.main.async { result(status) }
        }
      case "openNotificationSettings":
        let url: URL?
        if #available(iOS 16.0, *) {
          url = URL(string: UIApplication.openNotificationSettingsURLString)
        } else {
          url = URL(string: UIApplication.openSettingsURLString)
        }
        guard let url else {
          result(false)
          return
        }
        UIApplication.shared.open(url) { opened in
          DispatchQueue.main.async { result(opened) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureHealthMoodChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "florien/health_mood",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "Uygulama hazır değil.", details: nil))
        return
      }
      switch call.method {
      case "requestAuthorization":
        self.requestHealthAuthorization(result)
      case "saveDailyMood":
        self.saveDailyMood(call.arguments, result)
      case "readDailyMoods":
        self.readDailyMoods(call.arguments, result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func requestHealthAuthorization(_ result: @escaping FlutterResult) {
    guard #available(iOS 18.0, *), HKHealthStore.isHealthDataAvailable() else {
      resolve(result, value: false)
      return
    }
    let type = HKObjectType.stateOfMindType()
    healthStore.requestAuthorization(toShare: [type], read: [type]) { success, error in
      if let error {
        self.resolve(result, error: error)
        return
      }
      self.resolve(result, value: success)
    }
  }

  private func saveDailyMood(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard #available(iOS 18.0, *), HKHealthStore.isHealthDataAvailable() else {
      resolve(result, value: false)
      return
    }
    guard
      let values = arguments as? [String: Any],
      let timestamp = values["timestamp"] as? NSNumber,
      let valence = values["valence"] as? NSNumber
    else {
      result(FlutterError(code: "invalid_arguments", message: "Ruh hali bilgisi eksik.", details: nil))
      return
    }
    let mood = HKStateOfMind(
      date: Date(timeIntervalSince1970: timestamp.doubleValue / 1000),
      kind: .dailyMood,
      valence: min(max(valence.doubleValue, -1), 1),
      labels: [],
      associations: [],
      metadata: nil
    )
    healthStore.save(mood) { success, error in
      if let error {
        self.resolve(result, error: error)
        return
      }
      self.resolve(result, value: success)
    }
  }

  private func readDailyMoods(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard #available(iOS 18.0, *), HKHealthStore.isHealthDataAvailable() else {
      resolve(result, value: [])
      return
    }
    guard
      let values = arguments as? [String: Any],
      let timestamp = values["start"] as? NSNumber
    else {
      result(FlutterError(code: "invalid_arguments", message: "Başlangıç tarihi eksik.", details: nil))
      return
    }
    let start = Date(timeIntervalSince1970: timestamp.doubleValue / 1000)
    let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
    let type = HKObjectType.stateOfMindType()
    let query = HKSampleQuery(
      sampleType: type,
      predicate: HKQuery.predicateForSamples(withStart: start, end: end),
      limit: HKObjectQueryNoLimit,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
    ) { _, samples, error in
      if let error {
        self.resolve(result, error: error)
        return
      }
      let moods = (samples as? [HKStateOfMind] ?? [])
        .filter { $0.kind == .dailyMood }
        .map { mood in
          [
            "timestamp": Int(mood.startDate.timeIntervalSince1970 * 1000),
            "valence": mood.valence,
          ]
        }
      self.resolve(result, value: moods)
    }
    healthStore.execute(query)
  }

  private func resolve(_ result: @escaping FlutterResult, value: Any) {
    DispatchQueue.main.async { result(value) }
  }

  private func resolve(_ result: @escaping FlutterResult, error: Error) {
    DispatchQueue.main.async {
      result(FlutterError(code: "healthkit_error", message: error.localizedDescription, details: nil))
    }
  }
}
