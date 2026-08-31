import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Importacao de midia do dispositivo (galeria/camera/arquivos).
class MediaImportService {
  MediaImportService([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<XFile?> pickVideoFromGallery() {
    return _picker.pickVideo(source: ImageSource.gallery);
  }

  Future<XFile?> pickImageFromGallery() {
    return _picker.pickImage(source: ImageSource.gallery);
  }

  Future<XFile?> recordVideo() {
    return _picker.pickVideo(source: ImageSource.camera);
  }

  /// Audio via seletor de ARQUIVOS do sistema (galeria nao lista audio).
  Future<XFile?> pickAudioFile() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.audio, allowMultiple: false);
    final f = result?.files.single;
    if (f == null || f.path == null) return null;
    return XFile(f.path!, name: f.name);
  }
}

final mediaImportServiceProvider = Provider<MediaImportService>(
  (ref) => MediaImportService(),
);
