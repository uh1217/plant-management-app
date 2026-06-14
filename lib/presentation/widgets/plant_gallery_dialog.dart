import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:plantapp_p/core/di/service_locator.dart';
import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/domain/entities/gallery_photo.dart';
import 'package:plantapp_p/presentation/utils/image_helpers.dart';

const int _kMaxPhotos = 12;

class PlantGalleryDialog extends StatefulWidget {
  const PlantGalleryDialog({
    super.key,
    required this.plantId,
    required this.plantName,
  });

  final String plantId;
  final String plantName;

  @override
  State<PlantGalleryDialog> createState() => _PlantGalleryDialogState();
}

class _PlantGalleryDialogState extends State<PlantGalleryDialog> {
  List<GalleryPhoto> _photos = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await ServiceLocator.instance.getGalleryPhotosUseCase(
      widget.plantId,
    );
    if (!mounted) return;
    switch (result) {
      case Success(:final data):
        setState(() {
          _photos = data;
          _isLoading = false;
        });
      case Failure(:final message):
        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
    }
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= _kMaxPhotos || _isUploading) return;

    final status = await Permission.photos.request();
    if (!status.isGranted && !status.isLimited) {
      if (mounted) showPermissionRequestDialog(context);
      return;
    }

    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final compressed = await compressImage(xFile.path);
      final url = await uploadGalleryImageToStorage(
        compressed,
        widget.plantId,
      );
      final photo = GalleryPhoto(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        photoUrl: url,
        takenAt: DateTime.now().toIso8601String(),
        memo: '',
      );
      final result = await ServiceLocator.instance.addGalleryPhotoUseCase(
        widget.plantId,
        photo,
      );
      if (!mounted) return;
      switch (result) {
        case Success():
          setState(() => _photos = [photo, ..._photos]);
        case Failure(:final message):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진 업로드에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _openPhotoDetail(GalleryPhoto photo) {
    showDialog(
      context: context,
      builder: (_) => _PhotoDetailDialog(
        photo: photo,
        plantId: widget.plantId,
        onMemoSaved: (updatedPhoto) {
          setState(() {
            final idx = _photos.indexWhere((p) => p.id == updatedPhoto.id);
            if (idx != -1) {
              _photos = List.of(_photos)..[idx] = updatedPhoto;
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(colorScheme, theme),
            Flexible(child: _buildBody(colorScheme, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.photo_library, color: colorScheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '식물 기록 일지',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  widget.plantName,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
            ),
          Text(
            '${_photos.length}/$_kMaxPhotos',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.45),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: colorScheme.onSurface),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme, ThemeData theme) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: colorScheme.error.withOpacity(0.6)),
            const SizedBox(height: 12),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6))),
            const SizedBox(height: 16),
            TextButton(
                onPressed: _loadPhotos, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    final showAddButton = _photos.length < _kMaxPhotos;
    final itemCount = _photos.length + (showAddButton ? 1 : 0);

    if (itemCount == 0) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 56, color: colorScheme.onSurface.withOpacity(0.25)),
            const SizedBox(height: 12),
            Text(
              '아직 기록된 사진이 없어요\n+ 버튼을 눌러 첫 사진을 추가해보세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withOpacity(0.45),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            _buildAddButton(colorScheme),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1.0,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (showAddButton && index == itemCount - 1) {
            return _buildAddTile(colorScheme, theme);
          }
          return _buildPhotoTile(_photos[index], colorScheme);
        },
      ),
    );
  }

  Widget _buildPhotoTile(GalleryPhoto photo, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () => _openPhotoDetail(photo),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildThumbnail(photo.photoUrl, colorScheme),
            if (photo.memo.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notes, size: 10, color: Colors.white70),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          photo.memo,
                          style: const TextStyle(
                              fontSize: 9, color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(String url, ColorScheme colorScheme) {
    if (url.isEmpty) {
      return Container(
        color: colorScheme.onSurface.withOpacity(0.08),
        child: Icon(Icons.image_not_supported_outlined,
            color: colorScheme.onSurface.withOpacity(0.3)),
      );
    }
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: colorScheme.onSurface.withOpacity(0.08),
          child: const Center(
              child: CircularProgressIndicator(strokeWidth: 1.5)),
        ),
        errorWidget: (_, __, ___) => Container(
          color: colorScheme.onSurface.withOpacity(0.08),
          child: Icon(Icons.broken_image_outlined,
              color: colorScheme.onSurface.withOpacity(0.3)),
        ),
      );
    }
    return Image.file(File(url), fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: colorScheme.onSurface.withOpacity(0.08),
          child: Icon(Icons.broken_image_outlined,
              color: colorScheme.onSurface.withOpacity(0.3)),
        ));
  }

  Widget _buildAddTile(ColorScheme colorScheme, ThemeData theme) {
    return GestureDetector(
      onTap: _isUploading ? null : _addPhoto,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isUploading
                ? colorScheme.onSurface.withOpacity(0.15)
                : colorScheme.primary.withOpacity(0.4),
            width: 1.5,
          ),
          color: colorScheme.primary.withOpacity(0.05),
        ),
        child: _isUploading
            ? Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: colorScheme.primary))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate,
                      size: 28,
                      color: colorScheme.primary.withOpacity(0.7)),
                  const SizedBox(height: 4),
                  Text(
                    '사진 추가',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.primary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAddButton(ColorScheme colorScheme) {
    return OutlinedButton.icon(
      onPressed: _isUploading ? null : _addPhoto,
      icon: const Icon(Icons.add_photo_alternate, size: 18),
      label: const Text('사진 추가'),
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ── 사진 상세 다이얼로그 ───────────────────────────────────────────────────────

class _PhotoDetailDialog extends StatefulWidget {
  const _PhotoDetailDialog({
    required this.photo,
    required this.plantId,
    required this.onMemoSaved,
  });

  final GalleryPhoto photo;
  final String plantId;
  final void Function(GalleryPhoto updatedPhoto) onMemoSaved;

  @override
  State<_PhotoDetailDialog> createState() => _PhotoDetailDialogState();
}

class _PhotoDetailDialogState extends State<_PhotoDetailDialog> {
  late TextEditingController _memoController;
  bool _isSaving = false;
  bool _memoChanged = false;

  @override
  void initState() {
    super.initState();
    _memoController = TextEditingController(text: widget.photo.memo);
    _memoController.addListener(() {
      final changed = _memoController.text != widget.photo.memo;
      if (changed != _memoChanged) setState(() => _memoChanged = changed);
    });
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _saveMemo() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    FocusScope.of(context).unfocus();

    final updated = GalleryPhoto(
      id: widget.photo.id,
      photoUrl: widget.photo.photoUrl,
      takenAt: widget.photo.takenAt,
      memo: _memoController.text.trim(),
    );

    final result = await ServiceLocator.instance.addGalleryPhotoUseCase(
      widget.plantId,
      updated,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    switch (result) {
      case Success():
        widget.onMemoSaved(updated);
        setState(() => _memoChanged = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('메모가 저장되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      case Failure(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
    }
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.year}년 ${dt.month}월 ${dt.day}일';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailHeader(colorScheme, theme),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildImageArea(colorScheme),
                    _buildDateRow(colorScheme),
                    const Divider(height: 1),
                    _buildMemoSection(colorScheme, theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailHeader(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.photo, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            '사진 상세',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: colorScheme.onSurface),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildImageArea(ColorScheme colorScheme) {
    final url = widget.photo.photoUrl;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.zero),
      child: SizedBox(
        height: 260,
        child: InteractiveViewer(
          child: url.startsWith('http')
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) => Container(
                    color: colorScheme.onSurface.withOpacity(0.08),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: colorScheme.onSurface.withOpacity(0.08),
                    child: const Center(
                        child: Icon(Icons.broken_image, size: 48)),
                  ),
                )
              : Image.file(
                  File(url),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: colorScheme.onSurface.withOpacity(0.08),
                    child: const Center(
                        child: Icon(Icons.broken_image, size: 48)),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDateRow(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.calendar_today,
              size: 15, color: colorScheme.primary.withOpacity(0.8)),
          const SizedBox(width: 8),
          Text(
            _formatDate(widget.photo.takenAt),
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withOpacity(0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoSection(ColorScheme colorScheme, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.notes,
                  size: 15, color: colorScheme.onSurface.withOpacity(0.55)),
              const SizedBox(width: 6),
              Text(
                '메모',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _memoController,
            maxLines: 3,
            maxLength: 200,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: '이 사진에 대한 메모를 남겨보세요...',
              hintStyle: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.35),
                  fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: colorScheme.primary, width: 1.5),
              ),
              filled: true,
              fillColor: colorScheme.onSurface.withOpacity(0.03),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ElevatedButton.icon(
              onPressed: (_memoChanged && !_isSaving) ? _saveMemo : null,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_isSaving ? '저장 중...' : '메모 저장'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                disabledBackgroundColor:
                    colorScheme.onSurface.withOpacity(0.12),
                disabledForegroundColor:
                    colorScheme.onSurface.withOpacity(0.35),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
