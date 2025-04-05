import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Modelo para armazenar os dados da imagem e da cor selecionada
class WallPaintModel {
  /// Imagem original selecionada pelo usuário
  File? originalImage;

  /// Imagem modificada com a cor aplicada
  File? modifiedImage;

  /// Máscara de detecção da parede (para debug)
  File? wallMask;

  /// Máscara manual desenhada pelo usuário
  Uint8List? manualMask;

  /// Dimensões da imagem original
  Size? imageSize;

  /// Cor selecionada para aplicar na parede
  Color selectedColor;

  /// Tolerância para a detecção de cores (0-100)
  double colorTolerance;

  /// Opacidade da cor aplicada (0-100)
  double colorOpacity;

  /// Modo de detecção avançado
  bool advancedDetection;

  /// Modo de edição manual da máscara
  bool manualMaskMode;

  /// Usar editor de máscara poligonal (true) ou pintura livre (false)
  bool usePolygonMaskEditor;

  WallPaintModel({
    this.originalImage,
    this.modifiedImage,
    this.wallMask,
    this.manualMask,
    this.imageSize,
    this.selectedColor = Colors.blue,
    this.colorTolerance = 30.0,
    this.colorOpacity = 100.0,
    this.advancedDetection = true,
    this.manualMaskMode = false,
    this.usePolygonMaskEditor = true,
  });

  /// Verifica se há uma imagem original carregada
  bool get hasImage => originalImage != null;

  /// Verifica se há uma imagem modificada
  bool get hasModifiedImage => modifiedImage != null;

  /// Verifica se há uma máscara de parede
  bool get hasWallMask => wallMask != null;

  /// Verifica se há uma máscara manual
  bool get hasManualMask => manualMask != null;

  /// Limpa os dados do modelo
  void clear() {
    originalImage = null;
    modifiedImage = null;
    wallMask = null;
    manualMask = null;
    imageSize = null;
    selectedColor = Colors.blue;
    colorTolerance = 30.0;
    colorOpacity = 100.0;
    advancedDetection = true;
    manualMaskMode = false;
    usePolygonMaskEditor = true;
  }
}
