import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import '../models/wall_paint_model.dart';

class WallPaintProvider extends ChangeNotifier {
  final WallPaintModel _model = WallPaintModel();
  final ImagePicker _picker = ImagePicker();

  // Getters para acessar os dados do modelo
  File? get originalImage => _model.originalImage;
  File? get modifiedImage => _model.modifiedImage;
  File? get wallMask => _model.wallMask;
  Uint8List? get manualMask => _model.manualMask;
  Size? get imageSize => _model.imageSize;
  Color get selectedColor => _model.selectedColor;
  double get colorTolerance => _model.colorTolerance;
  double get colorOpacity => _model.colorOpacity;
  bool get hasImage => _model.hasImage;
  bool get hasModifiedImage => _model.hasModifiedImage;
  bool get hasWallMask => _model.hasWallMask;
  bool get hasManualMask => _model.hasManualMask;
  bool get advancedDetection => _model.advancedDetection;
  bool get manualMaskMode => _model.manualMaskMode;
  bool get usePolygonMaskEditor => _model.usePolygonMaskEditor;

  // Estado de carregamento
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Lista de traços para a máscara manual
  final List<List<Offset>> _strokes = [];
  List<List<Offset>> get strokes => _strokes;

  // Seleciona uma imagem da galeria
  Future<void> pickImageFromGallery() async {
    try {
      _setLoading(true);
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        _model.originalImage = File(pickedFile.path);
        _model.modifiedImage = null;
        _model.wallMask = null;
        _model.manualMask = null;
        _strokes.clear();

        // Obtém as dimensões da imagem
        final img.Image? decodedImage = img.decodeImage(
          await _model.originalImage!.readAsBytes(),
        );
        if (decodedImage != null) {
          _model.imageSize = Size(
            decodedImage.width.toDouble(),
            decodedImage.height.toDouble(),
          );
        }

        debugPrint('Imagem selecionada da galeria: ${pickedFile.path}');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erro ao selecionar imagem da galeria: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Captura uma imagem da câmera
  Future<void> captureImageFromCamera() async {
    try {
      _setLoading(true);
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        _model.originalImage = File(pickedFile.path);
        _model.modifiedImage = null;
        _model.wallMask = null;
        _model.manualMask = null;
        _strokes.clear();

        // Obtém as dimensões da imagem
        final img.Image? decodedImage = img.decodeImage(
          await _model.originalImage!.readAsBytes(),
        );
        if (decodedImage != null) {
          _model.imageSize = Size(
            decodedImage.width.toDouble(),
            decodedImage.height.toDouble(),
          );
        }

        debugPrint('Imagem capturada da câmera: ${pickedFile.path}');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erro ao capturar imagem da câmera: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Atualiza a cor selecionada
  void updateSelectedColor(Color color) {
    _model.selectedColor = color;
    debugPrint(
      'Cor atualizada: R:${color.red}, G:${color.green}, B:${color.blue}',
    );
    notifyListeners();
  }

  // Atualiza a tolerância de cor
  void updateColorTolerance(double tolerance) {
    _model.colorTolerance = tolerance;
    debugPrint('Tolerância atualizada: $tolerance');
    notifyListeners();
  }

  // Atualiza a opacidade da cor
  void updateColorOpacity(double opacity) {
    _model.colorOpacity = opacity;
    debugPrint('Opacidade atualizada: $opacity');
    notifyListeners();
  }

  // Alterna o modo de detecção avançado
  void toggleAdvancedDetection(bool value) {
    _model.advancedDetection = value;
    debugPrint('Modo de detecção avançado: $value');
    notifyListeners();
  }

  // Alterna o modo de edição manual da máscara
  void toggleManualMaskMode(bool value) {
    _model.manualMaskMode = value;
    debugPrint('Modo de edição manual da máscara: $value');
    notifyListeners();
  }

  // Alterna entre o editor de máscara poligonal e a pintura livre
  void togglePolygonMaskEditor(bool value) {
    _model.usePolygonMaskEditor = value;
    debugPrint('Usando editor de máscara poligonal: $value');
    notifyListeners();
  }

  // Adiciona um novo traço à máscara manual
  void startNewStroke() {
    _strokes.add([]);
    notifyListeners();
  }

  // Adiciona um ponto ao traço atual
  void addPointToStroke(Offset point) {
    if (_strokes.isNotEmpty) {
      _strokes.last.add(point);
      notifyListeners();
    }
  }

  // Gera a máscara manual a partir dos traços
  Future<void> generateManualMask() async {
    if (_model.imageSize == null || _strokes.isEmpty) return;

    try {
      _setLoading(true);

      // Cria um recorder para desenhar os traços
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // Obtém as dimensões da imagem original
      final double width = _model.imageSize!.width;
      final double height = _model.imageSize!.height;

      // Preenche o fundo com preto (áreas não selecionadas)
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = Colors.black,
      );

      // Desenha os traços em branco (áreas selecionadas)
      final Paint strokePaint =
          Paint()
            ..color = Colors.white
            ..strokeWidth =
                30.0 // Pincel mais grosso para facilitar a seleção
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke;

      // Desenha cada traço
      for (final List<Offset> stroke in _strokes) {
        if (stroke.length < 2) {
          // Se houver apenas um ponto, desenha um círculo
          if (stroke.length == 1) {
            canvas.drawCircle(
              stroke.first,
              15.0,
              Paint()..color = Colors.white,
            );
          }
          continue;
        }

        final Path path = Path();
        path.moveTo(stroke.first.dx, stroke.first.dy);

        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }

        canvas.drawPath(path, strokePaint);
      }

      // Preenche as áreas fechadas
      final Paint fillPaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;

      for (final List<Offset> stroke in _strokes) {
        if (stroke.length < 3) continue;

        final Path path = Path();
        path.moveTo(stroke.first.dx, stroke.first.dy);

        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }

        // Fecha o caminho se estiver próximo do início
        final double distanceToStart = (stroke.last - stroke.first).distance;
        if (distanceToStart < 50.0) {
          path.close();
          canvas.drawPath(path, fillPaint);
        }
      }

      // Aplica uma dilatação para expandir a área selecionada
      final Paint dilationPaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10.0
            ..strokeCap = StrokeCap.round;

      // Desenha novamente os traços com um pincel mais fino para suavizar as bordas
      for (final List<Offset> stroke in _strokes) {
        if (stroke.length < 2) continue;

        final Path path = Path();
        path.moveTo(stroke.first.dx, stroke.first.dy);

        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }

        canvas.drawPath(path, dilationPaint);
      }

      // Converte o desenho para uma imagem
      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(
        width.toInt(),
        height.toInt(),
      );

      // Converte a imagem para bytes
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData != null) {
        _model.manualMask = byteData.buffer.asUint8List();
        debugPrint('Máscara manual gerada com sucesso');
      }
    } catch (e) {
      debugPrint('Erro ao gerar máscara manual: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Gera uma máscara a partir de um polígono
  Future<void> generatePolygonMask() async {
    if (_model.imageSize == null || _strokes.isEmpty) return;

    try {
      _setLoading(true);
      debugPrint('Gerando máscara poligonal...');
      debugPrint(
        'Dimensões da imagem: ${_model.imageSize!.width}x${_model.imageSize!.height}',
      );
      debugPrint('Número de pontos no polígono: ${_strokes.first.length}');

      // Cria um recorder para desenhar o polígono
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // Obtém as dimensões da imagem original
      final double width = _model.imageSize!.width;
      final double height = _model.imageSize!.height;

      // Preenche o fundo com preto (áreas não selecionadas)
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = Colors.black,
      );

      // Verifica se temos pontos suficientes para formar um polígono
      if (_strokes.isNotEmpty && _strokes.first.length >= 3) {
        // Cria um caminho com os pontos do polígono
        final Path path = Path();
        final List<Offset> points = _strokes.first;

        // Imprime os pontos para debug
        for (int i = 0; i < points.length; i++) {
          debugPrint('Ponto $i: (${points[i].dx}, ${points[i].dy})');
        }

        // Move para o primeiro ponto
        path.moveTo(points.first.dx, points.first.dy);

        // Adiciona os demais pontos
        for (int i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }

        // Fecha o polígono
        path.close();

        // Preenche o polígono com branco
        final Paint fillPaint =
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.fill
              ..isAntiAlias = true;

        canvas.drawPath(path, fillPaint);

        // Desenha a borda do polígono para suavizar as bordas
        final Paint strokePaint =
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4.0
              ..strokeJoin = StrokeJoin.round
              ..strokeCap = StrokeCap.round
              ..isAntiAlias = true;

        canvas.drawPath(path, strokePaint);

        // Aplica uma dilatação para expandir a área selecionada
        final Paint dilationPaint =
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8.0
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..isAntiAlias = true;

        canvas.drawPath(path, dilationPaint);
      }

      // Converte o desenho para uma imagem
      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(
        width.toInt(),
        height.toInt(),
      );

      // Converte a imagem para bytes
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        _model.manualMask = byteData.buffer.asUint8List();
        debugPrint('Máscara poligonal gerada com sucesso');

        // Salva a máscara para debug (opcional)
        // await _saveMaskForDebug(byteData.buffer.asUint8List());
      } else {
        debugPrint('Erro: ByteData nulo ao gerar máscara poligonal');
      }
    } catch (e) {
      debugPrint('Erro ao gerar máscara poligonal: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Método auxiliar para salvar a máscara para debug
  Future<void> _saveMaskForDebug(Uint8List maskBytes) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = tempDir.path;
      final String fileName =
          'mask_debug_${DateTime.now().millisecondsSinceEpoch}.png';
      final File maskFile = File('$tempPath/$fileName');
      await maskFile.writeAsBytes(maskBytes);
      debugPrint('Máscara salva para debug em: ${maskFile.path}');
    } catch (e) {
      debugPrint('Erro ao salvar máscara para debug: $e');
    }
  }

  // Limpa a máscara manual
  void clearManualMask() {
    _strokes.clear();
    _model.manualMask = null;
    notifyListeners();
  }

  // Aplica a cor selecionada na imagem
  Future<void> applyColorToWall() async {
    if (_model.originalImage == null) {
      debugPrint('Nenhuma imagem original para processar');
      return;
    }

    try {
      _setLoading(true);
      debugPrint('Iniciando processamento da imagem...');

      // Lê a imagem original
      final Uint8List imageBytes = await _model.originalImage!.readAsBytes();
      debugPrint('Tamanho dos bytes da imagem: ${imageBytes.length}');

      final img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        debugPrint('Não foi possível decodificar a imagem');
        return;
      }

      debugPrint(
        'Imagem decodificada com sucesso. Dimensões: ${originalImage.width}x${originalImage.height}',
      );

      // Cria uma cópia da imagem para modificar
      final img.Image modifiedImage = img.copyResize(
        originalImage,
        width: originalImage.width,
        height: originalImage.height,
      );

      // Aplica a cor na imagem
      debugPrint('Aplicando máscara de cor...');

      img.Image? maskImage;

      // Verifica se deve usar a máscara manual ou a detecção automática
      if (_model.manualMaskMode || _model.hasManualMask) {
        // Usa a máscara manual desenhada pelo usuário
        if (_model.hasManualMask) {
          maskImage = await _applyManualMask(modifiedImage);
        } else {
          // Se estiver no modo manual mas não tiver máscara, gera uma
          await generateManualMask();
          if (_model.hasManualMask) {
            maskImage = await _applyManualMask(modifiedImage);
          }
        }
      } else {
        // Usa a detecção automática
        maskImage =
            _model.advancedDetection
                ? await _applyAdvancedColorMask(modifiedImage)
                : await _applySimpleColorMask(modifiedImage);
      }

      // Salva a imagem modificada
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = join(
        tempDir.path,
        'modified_image_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      debugPrint('Salvando imagem modificada em: $tempPath');

      final File modifiedFile = File(tempPath);
      final Uint8List pngBytes = img.encodePng(modifiedImage);
      await modifiedFile.writeAsBytes(pngBytes);
      debugPrint(
        'Imagem modificada salva com sucesso. Tamanho: ${pngBytes.length} bytes',
      );

      _model.modifiedImage = modifiedFile;

      // Salva a máscara se disponível
      if (maskImage != null) {
        final String maskPath = join(
          tempDir.path,
          'wall_mask_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        final File maskFile = File(maskPath);
        final Uint8List maskBytes = img.encodePng(maskImage);
        await maskFile.writeAsBytes(maskBytes);
        _model.wallMask = maskFile;
        debugPrint('Máscara de parede salva em: $maskPath');
      }

      notifyListeners();
      debugPrint('Notificação enviada para atualizar a UI');
    } catch (e) {
      debugPrint('Erro ao aplicar cor na imagem: $e');
      // Adiciona mais detalhes sobre o erro
      if (e is Error) {
        debugPrint('Stack trace: ${e.stackTrace}');
      }
    } finally {
      _setLoading(false);
    }
  }

  // Aplica a máscara manual na imagem
  Future<img.Image?> _applyManualMask(img.Image image) async {
    try {
      // Converte a cor selecionada para o formato RGB
      final int targetR = selectedColor.red;
      final int targetG = selectedColor.green;
      final int targetB = selectedColor.blue;

      // Calcula o valor alpha baseado na opacidade (0-255)
      final int alpha = (255 * (_model.colorOpacity / 100)).round();

      debugPrint(
        'Aplicando cor RGB($targetR,$targetG,$targetB) com opacidade $alpha (máscara manual)',
      );

      // Decodifica a máscara manual
      final img.Image? maskImage = img.decodeImage(_model.manualMask!);

      if (maskImage == null) {
        debugPrint('Não foi possível decodificar a máscara manual');
        return null;
      }

      debugPrint(
        'Dimensões da máscara: ${maskImage.width}x${maskImage.height}',
      );
      debugPrint('Dimensões da imagem: ${image.width}x${image.height}');

      // Verifica se as dimensões da máscara correspondem às da imagem original
      img.Image resizedMask;
      if (maskImage.width != image.width || maskImage.height != image.height) {
        debugPrint(
          'Redimensionando máscara para corresponder à imagem original',
        );
        // Redimensiona a máscara para corresponder à imagem original
        resizedMask = img.copyResize(
          maskImage,
          width: image.width,
          height: image.height,
          interpolation:
              img
                  .Interpolation
                  .cubic, // Usa interpolação cúbica para melhor qualidade
        );
      } else {
        resizedMask = maskImage;
      }

      // Cria uma cópia da máscara para retornar (para visualização)
      final img.Image maskCopy = img.copyResize(
        resizedMask,
        width: resizedMask.width,
        height: resizedMask.height,
      );

      int pixelsModified = 0;
      int totalPixels = 0;
      int whitePixels = 0;

      // Aplica a cor nas áreas brancas da máscara
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          try {
            totalPixels++;

            // Verifica se o pixel está dentro dos limites da máscara
            if (x < resizedMask.width && y < resizedMask.height) {
              final maskPixel = resizedMask.getPixel(x, y);
              final int maskR = maskPixel.r.toInt();

              // Se o pixel for branco na máscara (área selecionada)
              if (maskR > 127) {
                whitePixels++;
                final pixel = image.getPixel(x, y);
                final int originalR = pixel.r.toInt();
                final int originalG = pixel.g.toInt();
                final int originalB = pixel.b.toInt();
                final int originalA = pixel.a.toInt();

                // Mistura a cor original com a nova cor baseado na opacidade
                final int newR = _blendColorChannel(originalR, targetR, alpha);
                final int newG = _blendColorChannel(originalG, targetG, alpha);
                final int newB = _blendColorChannel(originalB, targetB, alpha);

                // Aplica a cor misturada
                image.setPixel(
                  x,
                  y,
                  img.ColorRgba8(newR, newG, newB, originalA),
                );
                pixelsModified++;
              }
            }
          } catch (e) {
            debugPrint('Erro ao processar pixel ($x,$y): $e');
          }
        }
      }

      debugPrint('Total de pixels: $totalPixels');
      debugPrint('Pixels brancos na máscara: $whitePixels');
      debugPrint('Pixels modificados: $pixelsModified');

      return maskCopy;
    } catch (e) {
      debugPrint('Erro ao aplicar máscara manual: $e');
      if (e is Error) {
        debugPrint('Stack trace: ${e.stackTrace}');
      }
      return null;
    }
  }

  // Mistura dois canais de cor baseado no valor alpha
  int _blendColorChannel(int original, int target, int alpha) {
    return original + ((target - original) * alpha ~/ 255);
  }

  // Método simples para aplicar a máscara de cor na imagem
  Future<img.Image?> _applySimpleColorMask(img.Image image) async {
    // Converte a cor selecionada para o formato RGB
    final int targetR = selectedColor.red;
    final int targetG = selectedColor.green;
    final int targetB = selectedColor.blue;

    // Valor de tolerância (0-255)
    final double tolerance =
        colorTolerance * 2.55; // Converte de 0-100 para 0-255

    // Calcula o valor alpha baseado na opacidade (0-255)
    final int alpha = (255 * (_model.colorOpacity / 100)).round();

    debugPrint(
      'Aplicando cor RGB($targetR,$targetG,$targetB) com tolerância $tolerance e opacidade $alpha (modo simples)',
    );

    int pixelsModified = 0;

    try {
      // Primeiro, vamos tentar identificar a cor predominante da parede
      Map<String, int> colorCounts = {};
      String dominantColorKey = "";
      int maxCount = 0;

      // Amostragem para encontrar a cor predominante
      for (int y = 0; y < image.height; y += 5) {
        for (int x = 0; x < image.width; x += 5) {
          try {
            final pixel = image.getPixel(x, y);
            final int r = pixel.r.toInt();
            final int g = pixel.g.toInt();
            final int b = pixel.b.toInt();

            // Simplifica a cor para reduzir a quantidade de cores únicas
            final int simplifiedR = (r ~/ 10) * 10;
            final int simplifiedG = (g ~/ 10) * 10;
            final int simplifiedB = (b ~/ 10) * 10;

            final String colorKey = "$simplifiedR:$simplifiedG:$simplifiedB";

            colorCounts[colorKey] = (colorCounts[colorKey] ?? 0) + 1;

            if ((colorCounts[colorKey] ?? 0) > maxCount) {
              maxCount = colorCounts[colorKey] ?? 0;
              dominantColorKey = colorKey;
            }
          } catch (e) {
            // Ignora erros na amostragem
          }
        }
      }

      // Extrai os componentes da cor predominante
      List<int> dominantRGB = [255, 255, 255]; // Branco como padrão
      if (dominantColorKey.isNotEmpty) {
        final parts = dominantColorKey.split(":");
        if (parts.length == 3) {
          dominantRGB = [
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          ];
        }
      }

      debugPrint(
        'Cor predominante detectada: RGB(${dominantRGB[0]},${dominantRGB[1]},${dominantRGB[2]})',
      );

      // Cria uma máscara para visualização
      img.Image maskImage = img.Image(width: image.width, height: image.height);

      // Aplica a cor nas áreas que correspondem à cor predominante
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          try {
            final pixel = image.getPixel(x, y);
            final int r = pixel.r.toInt();
            final int g = pixel.g.toInt();
            final int b = pixel.b.toInt();
            final int a = pixel.a.toInt();

            // Calcula a diferença em relação à cor predominante
            final double colorDiff =
                ((r - dominantRGB[0]).abs() +
                    (g - dominantRGB[1]).abs() +
                    (b - dominantRGB[2]).abs()) /
                3.0;

            // Se a diferença for menor que a tolerância, aplica a cor selecionada
            if (colorDiff < tolerance) {
              // Mistura a cor original com a nova cor baseado na opacidade
              final int newR = _blendColorChannel(r, targetR, alpha);
              final int newG = _blendColorChannel(g, targetG, alpha);
              final int newB = _blendColorChannel(b, targetB, alpha);

              // Aplica a cor misturada
              image.setPixel(x, y, img.ColorRgba8(newR, newG, newB, a));

              // Marca como branco na máscara
              maskImage.setPixel(x, y, img.ColorRgba8(255, 255, 255, 255));
              pixelsModified++;
            } else {
              // Marca como preto na máscara
              maskImage.setPixel(x, y, img.ColorRgba8(0, 0, 0, 255));
            }
          } catch (e) {
            debugPrint('Erro ao processar pixel ($x,$y): $e');
          }
        }
      }

      debugPrint(
        'Pixels modificados: $pixelsModified de ${image.width * image.height}',
      );
      return maskImage;
    } catch (e) {
      debugPrint('Erro durante o processamento da máscara de cor: $e');
      return null;
    }
  }

  // Método avançado para aplicar a máscara de cor na imagem
  Future<img.Image?> _applyAdvancedColorMask(img.Image image) async {
    // Converte a cor selecionada para o formato RGB
    final int targetR = selectedColor.red;
    final int targetG = selectedColor.green;
    final int targetB = selectedColor.blue;

    // Valor de tolerância (0-255)
    final double tolerance =
        colorTolerance * 2.55; // Converte de 0-100 para 0-255

    // Calcula o valor alpha baseado na opacidade (0-255)
    final int alpha = (255 * (_model.colorOpacity / 100)).round();

    debugPrint(
      'Aplicando cor RGB($targetR,$targetG,$targetB) com tolerância $tolerance e opacidade $alpha (modo avançado)',
    );

    int pixelsModified = 0;

    try {
      // Primeiro, vamos criar uma máscara para identificar a parede
      final img.Image mask = img.Image(
        width: image.width,
        height: image.height,
      );

      // Passo 1: Identificar regiões de cores semelhantes (possíveis paredes)
      Map<String, int> colorCounts = {};
      Map<String, List<_WallPoint>> colorPositions = {};

      // Amostragem para encontrar as cores predominantes
      for (int y = 0; y < image.height; y += 3) {
        for (int x = 0; x < image.width; x += 3) {
          try {
            final pixel = image.getPixel(x, y);
            final int r = pixel.r.toInt();
            final int g = pixel.g.toInt();
            final int b = pixel.b.toInt();

            // Simplifica a cor para reduzir a quantidade de cores únicas
            final int simplifiedR = (r ~/ 15) * 15;
            final int simplifiedG = (g ~/ 15) * 15;
            final int simplifiedB = (b ~/ 15) * 15;

            final String colorKey = "$simplifiedR:$simplifiedG:$simplifiedB";

            // Conta ocorrências de cada cor
            colorCounts[colorKey] = (colorCounts[colorKey] ?? 0) + 1;

            // Armazena posições de cada cor
            colorPositions[colorKey] = colorPositions[colorKey] ?? [];
            colorPositions[colorKey]!.add(_WallPoint(x, y));
          } catch (e) {
            // Ignora erros na amostragem
          }
        }
      }

      // Passo 2: Identificar as cores mais prováveis de serem paredes
      // Paredes geralmente ocupam grandes áreas contínuas e estão na parte superior da imagem

      // Ordena as cores por frequência
      List<MapEntry<String, int>> sortedColors =
          colorCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      // Pega as 5 cores mais frequentes para análise
      List<String> topColors = sortedColors.take(5).map((e) => e.key).toList();

      // Pontuação para cada cor baseada em critérios de "paredeabilidade"
      Map<String, double> wallScores = {};

      for (String colorKey in topColors) {
        List<_WallPoint> positions = colorPositions[colorKey] ?? [];
        if (positions.isEmpty) continue;

        // Critério 1: Quantidade de pixels (normalizado)
        double frequencyScore =
            (colorCounts[colorKey] ?? 0) / (image.width * image.height / 9);

        // Critério 2: Posição vertical (paredes tendem a estar mais na parte superior)
        double totalY = 0.0;
        for (var p in positions) {
          totalY += p.y.toDouble();
        }
        double avgY = totalY / positions.length;
        double verticalScore = 1.0 - (avgY / image.height);

        // Critério 3: Distribuição horizontal (paredes tendem a ser largas)
        Set<int> uniqueXValues = positions.map((p) => p.x).toSet();
        double horizontalScore = uniqueXValues.length / image.width;

        // Critério 4: Variação de cor (paredes tendem a ter cores mais uniformes)
        List<int> rgbValues =
            colorKey.split(':').map((s) => int.parse(s)).toList();
        double colorVariance =
            (rgbValues[0] - rgbValues[1]).abs().toDouble() +
            (rgbValues[1] - rgbValues[2]).abs().toDouble() +
            (rgbValues[0] - rgbValues[2]).abs().toDouble();
        double uniformityScore = 1.0 - (colorVariance / 765.0); // 765 = 255*3

        // Pontuação final ponderada
        wallScores[colorKey] =
            (frequencyScore * 0.4) +
            (verticalScore * 0.3) +
            (horizontalScore * 0.2) +
            (uniformityScore * 0.1);
      }

      // Encontra a cor com maior pontuação de "paredeabilidade"
      String mostLikelyWallColor = "";
      double highestScore = 0;

      for (var entry in wallScores.entries) {
        if (entry.value > highestScore) {
          highestScore = entry.value;
          mostLikelyWallColor = entry.key;
        }
      }

      // Extrai os componentes da cor da parede
      List<int> wallRGB = [255, 255, 255]; // Branco como padrão
      if (mostLikelyWallColor.isNotEmpty) {
        final parts = mostLikelyWallColor.split(":");
        if (parts.length == 3) {
          wallRGB = [
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          ];
        }
      }

      debugPrint(
        'Cor da parede detectada: RGB(${wallRGB[0]},${wallRGB[1]},${wallRGB[2]}) com pontuação $highestScore',
      );

      // Passo 3: Criar uma máscara para a parede
      // Primeiro, marca todos os pixels que correspondem à cor da parede
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          try {
            final pixel = image.getPixel(x, y);
            final int r = pixel.r.toInt();
            final int g = pixel.g.toInt();
            final int b = pixel.b.toInt();

            // Simplifica a cor atual
            final int simplifiedR = (r ~/ 15) * 15;
            final int simplifiedG = (g ~/ 15) * 15;
            final int simplifiedB = (b ~/ 15) * 15;

            // Calcula a diferença em relação à cor da parede
            final double colorDiffToWall =
                ((simplifiedR - wallRGB[0]).abs() +
                    (simplifiedG - wallRGB[1]).abs() +
                    (simplifiedB - wallRGB[2]).abs()) /
                3.0;

            // Se a diferença for menor que a tolerância, marca como parede na máscara
            if (colorDiffToWall < tolerance) {
              // Marca como branco na máscara (parede)
              mask.setPixel(x, y, img.ColorRgba8(255, 255, 255, 255));
            } else {
              // Marca como preto na máscara (não parede)
              mask.setPixel(x, y, img.ColorRgba8(0, 0, 0, 255));
            }
          } catch (e) {
            debugPrint('Erro ao processar pixel para máscara ($x,$y): $e');
          }
        }
      }

      // Passo 4: Refinar a máscara para remover ruídos e melhorar a detecção
      // Aplicar operações morfológicas para melhorar a máscara

      // Função para verificar se um pixel é branco na máscara
      bool isWhitePixel(int x, int y) {
        if (x < 0 || y < 0 || x >= mask.width || y >= mask.height) return false;
        final pixel = mask.getPixel(x, y);
        return pixel.r.toInt() > 127;
      }

      // Dilatação: expande áreas brancas
      img.Image dilatedMask = img.Image(width: mask.width, height: mask.height);
      for (int y = 0; y < mask.height; y++) {
        for (int x = 0; x < mask.width; x++) {
          bool hasWhiteNeighbor =
              isWhitePixel(x, y) ||
              isWhitePixel(x - 1, y) ||
              isWhitePixel(x + 1, y) ||
              isWhitePixel(x, y - 1) ||
              isWhitePixel(x, y + 1);

          if (hasWhiteNeighbor) {
            dilatedMask.setPixel(x, y, img.ColorRgba8(255, 255, 255, 255));
          } else {
            dilatedMask.setPixel(x, y, img.ColorRgba8(0, 0, 0, 255));
          }
        }
      }

      // Erosão: reduz áreas brancas
      img.Image erodedMask = img.Image(
        width: dilatedMask.width,
        height: dilatedMask.height,
      );
      for (int y = 0; y < dilatedMask.height; y++) {
        for (int x = 0; x < dilatedMask.width; x++) {
          // Função para verificar se um pixel é branco na máscara dilatada
          bool isDilatedWhitePixel(int x, int y) {
            if (x < 0 ||
                y < 0 ||
                x >= dilatedMask.width ||
                y >= dilatedMask.height)
              return false;
            final pixel = dilatedMask.getPixel(x, y);
            return pixel.r.toInt() > 127;
          }

          bool allWhiteNeighbors =
              isDilatedWhitePixel(x, y) &&
              isDilatedWhitePixel(x - 1, y) &&
              isDilatedWhitePixel(x + 1, y) &&
              isDilatedWhitePixel(x, y - 1) &&
              isDilatedWhitePixel(x, y + 1);

          if (allWhiteNeighbors) {
            erodedMask.setPixel(x, y, img.ColorRgba8(255, 255, 255, 255));
          } else {
            erodedMask.setPixel(x, y, img.ColorRgba8(0, 0, 0, 255));
          }
        }
      }

      // Passo 5: Aplicar a cor na imagem usando a máscara refinada
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          try {
            // Verifica se o pixel está na máscara (é parede)
            final maskPixel = erodedMask.getPixel(x, y);

            // Se o pixel for branco na máscara (parede), aplica a cor
            if (maskPixel.r.toInt() > 127) {
              final pixel = image.getPixel(x, y);
              final int r = pixel.r.toInt();
              final int g = pixel.g.toInt();
              final int b = pixel.b.toInt();
              final int a = pixel.a.toInt();

              // Mistura a cor original com a nova cor baseado na opacidade
              final int newR = _blendColorChannel(r, targetR, alpha);
              final int newG = _blendColorChannel(g, targetG, alpha);
              final int newB = _blendColorChannel(b, targetB, alpha);

              // Aplica a cor misturada
              image.setPixel(x, y, img.ColorRgba8(newR, newG, newB, a));
              pixelsModified++;
            }
          } catch (e) {
            debugPrint('Erro ao aplicar cor ($x,$y): $e');
          }
        }
      }

      debugPrint(
        'Pixels modificados: $pixelsModified de ${image.width * image.height}',
      );
      return erodedMask;
    } catch (e) {
      debugPrint('Erro durante o processamento da máscara de cor: $e');
      return null;
    }
  }

  // Limpa os dados do modelo
  void clearData() {
    _model.clear();
    debugPrint('Dados limpos');
    notifyListeners();
  }

  // Limpa apenas a imagem modificada, mantendo a original
  void clearModifiedImage() {
    _model.modifiedImage = null;
    _model.wallMask = null;
    debugPrint('Imagem modificada limpa');
    notifyListeners();
  }

  // Atualiza o estado de carregamento
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

// Classe auxiliar para armazenar coordenadas de pontos
class _WallPoint {
  final int x;
  final int y;
  _WallPoint(this.x, this.y);
}
