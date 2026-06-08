import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

void showPermissionRequestDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('갤러리 접근 권한 필요'),
      content: const Text(
        '식물 사진을 등록하기 위해서는 갤러리 접근 권한이 반드시 필요합니다.\n\n'
        '지금 설정 화면으로 이동하여 [사진] 권한을 허용해 주세요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('나중에', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            openAppSettings();
          },
          child: const Text('설정으로 이동'),
        ),
      ],
    ),
  );
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
