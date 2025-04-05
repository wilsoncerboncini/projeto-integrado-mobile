import 'dart:io';
import 'package:flutter/material.dart';
import '../services/wall_paint_provider.dart';

/// Widget para edição manual da máscara
class MaskEditorWidget extends StatefulWidget {
  final File image;
  final WallPaintProvider provider;
  final VoidCallback onComplete;

  const MaskEditorWidget({
    Key? key,
    required this.image,
    required this.provider,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<MaskEditorWidget> createState() => _MaskEditorWidgetState();
}

class _MaskEditorWidgetState extends State<MaskEditorWidget> {
  bool _isDrawing = false;
  double _brushSize = 20.0;

  // Lista local de traços para renderização imediata
  final List<List<Offset>> _localStrokes = [];

  // Para armazenar as dimensões da imagem na tela
  final GlobalKey _imageKey = GlobalKey();
  Size _imageSize = Size.zero;
  Rect _imageRect = Rect.zero;

  // Para rastrear a posição atual do cursor
  Offset _lastPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    // Inicializa a lista local com os traços existentes do provider
    _localStrokes.addAll(widget.provider.strokes);

    // Agenda a medição do tamanho da imagem após a renderização
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateImageSize();
    });
  }

  // Atualiza as dimensões da imagem na tela
  void _updateImageSize() {
    final RenderBox? renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() {
        _imageSize = renderBox.size;
        _imageRect = renderBox.localToGlobal(Offset.zero) & _imageSize;
      });
    }
  }

  // Converte coordenadas da tela para coordenadas da imagem original
  Offset _convertToImageCoordinates(Offset screenPosition) {
    if (_imageSize == Size.zero || widget.provider.imageSize == null) {
      return screenPosition;
    }

    // Calcula a posição relativa dentro do widget de imagem
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localPosition = renderBox.globalToLocal(screenPosition);

    // Ajusta para a posição dentro da imagem (considerando o BoxFit.contain)
    final double imageAspectRatio =
        widget.provider.imageSize!.width / widget.provider.imageSize!.height;
    final double screenAspectRatio = _imageSize.width / _imageSize.height;

    double imageDisplayWidth = _imageSize.width;
    double imageDisplayHeight = _imageSize.height;

    // Ajusta as dimensões com base no BoxFit.contain
    if (imageAspectRatio > screenAspectRatio) {
      // Imagem mais larga que a tela
      imageDisplayHeight = _imageSize.width / imageAspectRatio;
    } else {
      // Imagem mais alta que a tela
      imageDisplayWidth = _imageSize.height * imageAspectRatio;
    }

    // Calcula os offsets para centralizar a imagem
    final double offsetX = (_imageSize.width - imageDisplayWidth) / 2;
    final double offsetY = (_imageSize.height - imageDisplayHeight) / 2;

    // Ajusta a posição considerando os offsets
    final double relativeX = (localPosition.dx - offsetX) / imageDisplayWidth;
    final double relativeY = (localPosition.dy - offsetY) / imageDisplayHeight;

    // Converte para coordenadas da imagem original
    return Offset(
      relativeX * widget.provider.imageSize!.width,
      relativeY * widget.provider.imageSize!.height,
    );
  }

  // Converte coordenadas da imagem original para coordenadas da tela
  Offset _convertToScreenCoordinates(Offset imagePosition) {
    if (_imageSize == Size.zero || widget.provider.imageSize == null) {
      return imagePosition;
    }

    // Calcula a posição relativa dentro da imagem original
    final double relativeX =
        imagePosition.dx / widget.provider.imageSize!.width;
    final double relativeY =
        imagePosition.dy / widget.provider.imageSize!.height;

    // Ajusta para a posição na tela (considerando o BoxFit.contain)
    final double imageAspectRatio =
        widget.provider.imageSize!.width / widget.provider.imageSize!.height;
    final double screenAspectRatio = _imageSize.width / _imageSize.height;

    double imageDisplayWidth = _imageSize.width;
    double imageDisplayHeight = _imageSize.height;

    // Ajusta as dimensões com base no BoxFit.contain
    if (imageAspectRatio > screenAspectRatio) {
      // Imagem mais larga que a tela
      imageDisplayHeight = _imageSize.width / imageAspectRatio;
    } else {
      // Imagem mais alta que a tela
      imageDisplayWidth = _imageSize.height * imageAspectRatio;
    }

    // Calcula os offsets para centralizar a imagem
    final double offsetX = (_imageSize.width - imageDisplayWidth) / 2;
    final double offsetY = (_imageSize.height - imageDisplayHeight) / 2;

    // Converte para coordenadas da tela
    return Offset(
      relativeX * imageDisplayWidth + offsetX,
      relativeY * imageDisplayHeight + offsetY,
    );
  }

  // Calcula o tamanho do pincel ajustado para a escala da imagem
  double get _adjustedBrushSize {
    if (_imageSize == Size.zero || widget.provider.imageSize == null) {
      return _brushSize;
    }

    // Calcula a escala da imagem na tela
    final double imageAspectRatio =
        widget.provider.imageSize!.width / widget.provider.imageSize!.height;
    final double screenAspectRatio = _imageSize.width / _imageSize.height;

    double scale;
    if (imageAspectRatio > screenAspectRatio) {
      // Imagem mais larga que a tela
      scale = _imageSize.width / widget.provider.imageSize!.width;
    } else {
      // Imagem mais alta que a tela
      scale = _imageSize.height / widget.provider.imageSize!.height;
    }

    return _brushSize * scale;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Imagem original
              Image.file(widget.image, fit: BoxFit.contain, key: _imageKey),

              // Área de desenho
              GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Container(
                  color: Colors.transparent,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),

              // Traços da máscara (usando a lista local para renderização imediata)
              CustomPaint(
                painter: _MaskPainter(
                  strokes: _localStrokes,
                  brushSize: _brushSize,
                  color: widget.provider.selectedColor.withOpacity(0.5),
                  imageSize: _imageSize,
                  originalImageSize: widget.provider.imageSize,
                ),
              ),

              // Cursor personalizado para mostrar o tamanho do pincel
              if (_isDrawing)
                Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CursorPainter(
                        position: _lastPosition,
                        brushSize: _adjustedBrushSize,
                        color: widget.provider.selectedColor.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),

              // Instruções
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  color: Colors.black.withOpacity(0.6),
                  child: const Text(
                    'Pinte as áreas onde deseja aplicar a cor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Controles de edição
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Controle de tamanho do pincel
              Row(
                children: [
                  const Icon(Icons.brush, size: 16),
                  const SizedBox(width: 8),
                  const Text('Tamanho do pincel:'),
                  Expanded(
                    child: Slider(
                      value: _brushSize,
                      min: 5.0,
                      max: 50.0,
                      divisions: 9,
                      label: _brushSize.round().toString(),
                      onChanged: (value) {
                        setState(() {
                          _brushSize = value;
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Botões de ação
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.provider.clearManualMask();
                      setState(() {
                        _localStrokes.clear();
                      });
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Limpar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await widget.provider.generateManualMask();
                      widget.onComplete();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Concluir'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onPanStart(DragStartDetails details) {
    // Atualiza a posição do cursor
    _lastPosition = details.localPosition;

    // Converte a posição para coordenadas da imagem original
    final Offset imagePosition = _convertToImageCoordinates(
      details.globalPosition,
    );

    // Adiciona um novo traço ao provider
    widget.provider.startNewStroke();
    widget.provider.addPointToStroke(imagePosition);

    // Adiciona um novo traço à lista local
    setState(() {
      _localStrokes.add([imagePosition]);
      _isDrawing = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDrawing) return;

    // Atualiza a posição do cursor
    setState(() {
      _lastPosition = details.localPosition;
    });

    // Converte a posição para coordenadas da imagem original
    final Offset imagePosition = _convertToImageCoordinates(
      details.globalPosition,
    );

    // Adiciona o ponto ao provider
    widget.provider.addPointToStroke(imagePosition);

    // Adiciona o ponto à lista local e força a reconstrução
    setState(() {
      if (_localStrokes.isNotEmpty) {
        _localStrokes.last.add(imagePosition);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDrawing = false;
    });
  }
}

/// Painter para desenhar os traços da máscara
class _MaskPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final double brushSize;
  final Color color;
  final Size? imageSize;
  final Size? originalImageSize;

  _MaskPainter({
    required this.strokes,
    required this.brushSize,
    required this.color,
    this.imageSize,
    this.originalImageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize == null || originalImageSize == null || imageSize!.isEmpty) {
      return;
    }

    final Paint paint =
        Paint()
          ..color = color
          ..strokeWidth = _getAdjustedBrushSize()
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

    // Calcula as dimensões e posição da imagem na tela
    final double imageAspectRatio =
        originalImageSize!.width / originalImageSize!.height;
    final double screenAspectRatio = imageSize!.width / imageSize!.height;

    double displayWidth = imageSize!.width;
    double displayHeight = imageSize!.height;

    // Ajusta as dimensões com base no BoxFit.contain
    if (imageAspectRatio > screenAspectRatio) {
      // Imagem mais larga que a tela
      displayHeight = imageSize!.width / imageAspectRatio;
    } else {
      // Imagem mais alta que a tela
      displayWidth = imageSize!.height * imageAspectRatio;
    }

    // Calcula os offsets para centralizar a imagem
    final double offsetX = (imageSize!.width - displayWidth) / 2;
    final double offsetY = (imageSize!.height - displayHeight) / 2;

    // Desenha cada traço
    for (final List<Offset> stroke in strokes) {
      if (stroke.isEmpty) continue;

      if (stroke.length == 1) {
        // Se houver apenas um ponto, desenha um círculo
        final Offset screenPoint = _convertToScreenCoordinates(stroke.first);
        canvas.drawCircle(screenPoint, _getAdjustedBrushSize() / 2, paint);
        continue;
      }

      final Path path = Path();
      final Offset firstPoint = _convertToScreenCoordinates(stroke.first);
      path.moveTo(firstPoint.dx, firstPoint.dy);

      for (int i = 1; i < stroke.length; i++) {
        final Offset screenPoint = _convertToScreenCoordinates(stroke[i]);
        path.lineTo(screenPoint.dx, screenPoint.dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  // Converte coordenadas da imagem original para coordenadas da tela
  Offset _convertToScreenCoordinates(Offset imagePosition) {
    if (imageSize == null || originalImageSize == null || imageSize!.isEmpty) {
      return imagePosition;
    }

    // Calcula a posição relativa dentro da imagem original
    final double relativeX = imagePosition.dx / originalImageSize!.width;
    final double relativeY = imagePosition.dy / originalImageSize!.height;

    // Ajusta para a posição na tela (considerando o BoxFit.contain)
    final double imageAspectRatio =
        originalImageSize!.width / originalImageSize!.height;
    final double screenAspectRatio = imageSize!.width / imageSize!.height;

    double displayWidth = imageSize!.width;
    double displayHeight = imageSize!.height;

    // Ajusta as dimensões com base no BoxFit.contain
    if (imageAspectRatio > screenAspectRatio) {
      // Imagem mais larga que a tela
      displayHeight = imageSize!.width / imageAspectRatio;
    } else {
      // Imagem mais alta que a tela
      displayWidth = imageSize!.height * imageAspectRatio;
    }

    // Calcula os offsets para centralizar a imagem
    final double offsetX = (imageSize!.width - displayWidth) / 2;
    final double offsetY = (imageSize!.height - displayHeight) / 2;

    // Converte para coordenadas da tela
    return Offset(
      relativeX * displayWidth + offsetX,
      relativeY * displayHeight + offsetY,
    );
  }

  // Calcula o tamanho do pincel ajustado para a escala da imagem
  double _getAdjustedBrushSize() {
    if (imageSize == null || originalImageSize == null || imageSize!.isEmpty) {
      return brushSize;
    }

    // Calcula a escala da imagem na tela
    final double imageAspectRatio =
        originalImageSize!.width / originalImageSize!.height;
    final double screenAspectRatio = imageSize!.width / imageSize!.height;

    double scale;
    if (imageAspectRatio > screenAspectRatio) {
      // Imagem mais larga que a tela
      scale = imageSize!.width / originalImageSize!.width;
    } else {
      // Imagem mais alta que a tela
      scale = imageSize!.height / originalImageSize!.height;
    }

    return brushSize * scale;
  }

  @override
  bool shouldRepaint(_MaskPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.brushSize != brushSize ||
        oldDelegate.color != color ||
        oldDelegate.imageSize != imageSize;
  }
}

/// Painter para desenhar o cursor personalizado
class _CursorPainter extends CustomPainter {
  final Offset position;
  final double brushSize;
  final Color color;

  _CursorPainter({
    required this.position,
    required this.brushSize,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Desenha um círculo na posição do cursor
    final Paint paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    canvas.drawCircle(position, brushSize / 2, paint);

    // Desenha um ponto no centro
    final Paint centerPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    canvas.drawCircle(position, 2.0, centerPaint);
  }

  @override
  bool shouldRepaint(_CursorPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.brushSize != brushSize ||
        oldDelegate.color != color;
  }
}
