import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../domain/laboratory_session.dart';

/// Le uma vez os dados que identificam a execucao no relatorio.
///
/// O Laboratorio nao precisa de identificadores pessoais: somente o modelo do
/// aparelho, o sistema, a versao do app e o locale usados no teste.
abstract final class LaboratoryEnvironmentService {
  static Future<LaboratoryEnvironment> read() async {
    final package = await _packageInfo();
    final appVersion = package == null
        ? 'versao desconhecida'
        : '${package.version}+${package.buildNumber}';
    final locale = WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final device = await deviceInfo.androidInfo;
        final manufacturer = device.manufacturer.trim();
        final model = device.model.trim();
        return LaboratoryEnvironment(
          deviceModel: [
            if (manufacturer.isNotEmpty) manufacturer,
            if (model.isNotEmpty && model.toLowerCase() != manufacturer.toLowerCase()) model,
          ].join(' ').trim(),
          operatingSystem:
              'Android ${device.version.release} (SDK ${device.version.sdkInt})',
          appVersion: appVersion,
          locale: locale,
        );
      }
      if (Platform.isIOS) {
        final device = await deviceInfo.iosInfo;
        final commercialName = device.modelName.trim();
        return LaboratoryEnvironment(
          deviceModel: commercialName.isEmpty
              ? '${device.model} (${device.utsname.machine})'
              : '$commercialName (${device.utsname.machine})',
          operatingSystem: '${device.systemName} ${device.systemVersion}',
          appVersion: appVersion,
          locale: locale,
        );
      }
    } on Object {
      // O relatorio continua util mesmo quando um plugin de plataforma nao
      // responde (por exemplo, em um teste de widget).
    }

    return LaboratoryEnvironment(
      deviceModel: _fallbackDeviceModel(),
      operatingSystem: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      appVersion: appVersion,
      locale: locale,
    );
  }

  static Future<PackageInfo?> _packageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } on Object {
      return null;
    }
  }

  static String _fallbackDeviceModel() {
    if (kIsWeb) return 'Navegador';
    final hostname = Platform.localHostname.trim();
    return hostname.isEmpty ? 'Dispositivo desconhecido' : hostname;
  }
}
