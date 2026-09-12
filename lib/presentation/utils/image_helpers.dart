import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const kDefaultPlantImageAsset = 'assets/images/home_gardening.jpg';

/// 대표 사진 표시. 빈 값·에셋 경로는 [kDefaultPlantImageAsset]을 Image.asset으로 연다.
/// (에셋 경로를 Image.file로 열면 iOS에서 카드 빌드가 실패할 수 있다.)
Widget buildPlantImage({
  required String imageUrl,
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  final asset = imageUrl.isEmpty
      ? kDefaultPlantImageAsset
      : (imageUrl.startsWith('assets/') ? imageUrl : null);
  if (asset != null) {
    return Image.asset(asset, width: width, height: height, fit: fit);
  }
  if (imageUrl.startsWith('http')) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => SizedBox(
        width: width,
        height: height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, __, ___) => Image.asset(
        kDefaultPlantImageAsset,
        width: width,
        height: height,
        fit: fit,
      ),
    );
  }
  return Image.file(
    File(imageUrl),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, __, ___) => Image.asset(
      kDefaultPlantImageAsset,
      width: width,
      height: height,
      fit: fit,
    ),
  );
}

/// 시스템 사진 선택 도구로 갤러리에서 한 장을 고른다.
/// [requestFullMetadata]를 끄면 Android 13+에서 READ_MEDIA_IMAGES가 필요 없다.
Future<XFile?> pickGalleryImage({int? imageQuality}) {
  return ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: imageQuality,
    requestFullMetadata: false,
  );
}

/// 갤러리 이미지 압축 (input/list 공용)
Future<String> compressImage(String path) async {
  final appDir = await getApplicationDocumentsDirectory();
  final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
  final targetPath = p.join(appDir.path, fileName);

  final compressedFile = await FlutterImageCompress.compressAndGetFile(
    path,
    targetPath,
    quality: 80,
    minWidth: 1024,
    minHeight: 1024,
    format: CompressFormat.jpeg,
  );

  return compressedFile?.path ?? path;
}

/// 로컬 이미지를 Firebase Storage에 업로드하고 다운로드 URL을 반환
/// 저장 경로: users/{uid}/plants/{타임스탬프}.jpg
Future<String> uploadImageToStorage(String localPath) async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
  final ref = FirebaseStorage.instance
      .ref()
      .child('users/$uid/plants/$fileName');
  await ref.putFile(File(localPath));
  return await ref.getDownloadURL();
}

/// 갤러리 사진을 Firebase Storage에 업로드하고 다운로드 URL을 반환
/// 저장 경로: users/{uid}/plants/{plantId}/gallery/{타임스탬프}.jpg
Future<String> uploadGalleryImageToStorage(
    String localPath, String plantId) async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
  final ref = FirebaseStorage.instance
      .ref()
      .child('users/$uid/plants/$plantId/gallery/$fileName');
  await ref.putFile(File(localPath));
  return await ref.getDownloadURL();
}

void showStorageFullDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('저장공간 부족'),
      content: const Text(
        '휴대폰의 저장공간이 부족하여 데이터를 저장할 수 없습니다.\n\n'
        '불필요한 앱이나 파일을 정리한 후 다시 시도해 주세요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}
