import 'dart:io';
import 'package:flutter/material.dart';

/// Widget para exibir a pré-visualização da imagem
class ImagePreviewWidget extends StatelessWidget {
  final File? image;
  final String placeholder;
  final double height;
  final BoxFit fit;
  final VoidCallback? onTap;

  const ImagePreviewWidget({
    Key? key,
    required this.image,
    this.placeholder = 'Nenhuma imagem selecionada',
    this.height = 300,
    this.fit = BoxFit.contain,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (image == null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.image,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  placeholder,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            image!,
            fit: fit,
            height: height,
            width: double.infinity,
          ),
        ),
      ),
    );
  }
} 