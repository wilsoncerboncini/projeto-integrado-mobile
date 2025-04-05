import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/wall_paint_provider.dart';

/// Widget para edição manual da máscara usando seleção poligonal
class PolygonMaskEditorWidget extends StatefulWidget {
  final File image;
  final WallPaintProvider provider;
  final VoidCallback onComplete;

  const PolygonMaskEditorWidget({
    Key? key,
    required this.image,
    required this.provider,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<PolygonMaskEditorWidget> createState() =>
      _PolygonMaskEditorWidgetState();
}

class _PolygonMaskEditorWidgetState extends State<PolygonMaskEditorWidget> {
  // Para armazenar as dimensões da imagem na tela
  final GlobalKey _imageKey = GlobalKey();
  Size _imageSize = Size.zero;
  Rect _imageRect = Rect.zero;

  // Lista de pontos do polígono (em coordenadas da imagem original)
  final List<Offset> _polygonPoints = [];

  // Ponto que está sendo arrastado atualmente
  int _dragPointIndex = -1;

  // Ponto que está sendo inserido entre dois pontos existentes
  int _insertPointIndex = -1;

  // Tamanho do nó para interação
  double _nodeSize = 20.0;

  // Distância máxima para considerar um clique em uma aresta
  final double _edgeDetectionThreshold = 20.0;

  // Estado inicial do polígono já foi criado
  bool _initialPolygonCreated = false;

  // Modo de edição (arrastar ou selecionar)
  bool _dragMode =
      true; // Iniciar com modo de arrasto ativado para facilitar no emulador

  // Nó selecionado atualmente (para modo de edição)
  int _selectedNodeIndex = -1;

  @override
  void initState() {
    super.initState();

    // Limpa os pontos existentes
    _polygonPoints.clear();
    _initialPolygonCreated = false;
    _dragPointIndex = -1;
    _selectedNodeIndex = -1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Agenda a medição do tamanho da imagem após a renderização
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateImageSize();

        // Agenda verificações adicionais para garantir que a imagem seja medida corretamente
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _updateImageSize();
        });

        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _updateImageSize();
        });
      }
    });
  }

  // Atualiza as dimensões da imagem na tela
  void _updateImageSize() {
    final RenderBox? renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final Size newSize = renderBox.size;
      final Rect newRect = renderBox.localToGlobal(Offset.zero) & newSize;

      // Verifica se as dimensões mudaram
      bool sizeChanged = _imageSize != newSize || _imageRect != newRect;

      if (sizeChanged) {
        debugPrint(
          'Dimensões da imagem atualizadas: $newSize (anterior: $_imageSize)',
        );
        debugPrint('Retângulo da imagem: $newRect');

        setState(() {
          _imageSize = newSize;
          _imageRect = newRect;

          // Cria o polígono inicial se ainda não foi criado ou se as dimensões mudaram significativamente
          if (!_initialPolygonCreated && widget.provider.imageSize != null) {
            _createInitialPolygon();
          } else if (_initialPolygonCreated &&
              sizeChanged &&
              _polygonPoints.isNotEmpty) {
            // Se as dimensões mudaram e já temos um polígono, recria-o para manter a proporção
            _createInitialPolygon();
          }
        });
      }
    } else {
      debugPrint('RenderBox não disponível para a imagem');
      // Agenda uma nova tentativa
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _updateImageSize();
        }
      });
    }
  }

  // Cria o polígono inicial (retângulo que ocupa 80% da imagem)
  void _createInitialPolygon() {
    if (widget.provider.imageSize == null) return;

    // Limpa os pontos existentes
    _polygonPoints.clear();

    // Agenda a criação do polígono após a renderização
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // Obtém a posição e tamanho real da imagem na tela
        final RenderBox? renderBox =
            _imageKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) {
          debugPrint('RenderBox não disponível para a imagem');
          _createInitialPolygonFallback();
          return;
        }

        final Size actualImageSize = renderBox.size;
        final Offset imageGlobalPosition = renderBox.localToGlobal(Offset.zero);

        debugPrint('Tamanho real da imagem na tela: $actualImageSize');
        debugPrint('Posição global da imagem: $imageGlobalPosition');

        // Calcula as dimensões reais da imagem exibida (considerando BoxFit.contain)
        final double imageAspectRatio =
            widget.provider.imageSize!.width /
            widget.provider.imageSize!.height;
        final double screenAspectRatio =
            actualImageSize.width / actualImageSize.height;

        double displayWidth, displayHeight;
        double offsetX = 0, offsetY = 0;

        if (imageAspectRatio > screenAspectRatio) {
          // Imagem limitada pela largura
          displayWidth = actualImageSize.width;
          displayHeight = displayWidth / imageAspectRatio;
          offsetY = (actualImageSize.height - displayHeight) / 2;
        } else {
          // Imagem limitada pela altura
          displayHeight = actualImageSize.height;
          displayWidth = displayHeight * imageAspectRatio;
          offsetX = (actualImageSize.width - displayWidth) / 2;
        }

        // Calcula as coordenadas do retângulo (10% de margem em cada lado)
        // Estas coordenadas são em relação à imagem exibida, não à imagem original
        final double marginX = displayWidth * 0.1;
        final double marginY = displayHeight * 0.1;

        final double screenLeft = offsetX + marginX;
        final double screenTop = offsetY + marginY;
        final double screenRight = offsetX + displayWidth - marginX;
        final double screenBottom = offsetY + displayHeight - marginY;

        debugPrint(
          'Coordenadas do retângulo na tela: ($screenLeft, $screenTop) - ($screenRight, $screenBottom)',
        );

        // Converte as coordenadas da tela para coordenadas da imagem original
        final double normalizedLeft = (screenLeft - offsetX) / displayWidth;
        final double normalizedTop = (screenTop - offsetY) / displayHeight;
        final double normalizedRight = (screenRight - offsetX) / displayWidth;
        final double normalizedBottom =
            (screenBottom - offsetY) / displayHeight;

        final double imageLeft =
            normalizedLeft * widget.provider.imageSize!.width;
        final double imageTop =
            normalizedTop * widget.provider.imageSize!.height;
        final double imageRight =
            normalizedRight * widget.provider.imageSize!.width;
        final double imageBottom =
            normalizedBottom * widget.provider.imageSize!.height;

        debugPrint(
          'Coordenadas do retângulo na imagem original: ($imageLeft, $imageTop) - ($imageRight, $imageBottom)',
        );

        // Adiciona os pontos do retângulo
        setState(() {
          _polygonPoints.add(Offset(imageLeft, imageTop)); // Superior esquerdo
          _polygonPoints.add(Offset(imageRight, imageTop)); // Superior direito
          _polygonPoints.add(
            Offset(imageRight, imageBottom),
          ); // Inferior direito
          _polygonPoints.add(
            Offset(imageLeft, imageBottom),
          ); // Inferior esquerdo
          _initialPolygonCreated = true;

          // Força uma atualização da UI
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        });
      } catch (e) {
        debugPrint('Erro ao criar polígono inicial: $e');
        // Fallback para o método original se houver erro
        _createInitialPolygonFallback();
      }
    });
  }

  // Método de fallback para criar o polígono inicial
  void _createInitialPolygonFallback() {
    if (widget.provider.imageSize == null) return;

    final double width = widget.provider.imageSize!.width;
    final double height = widget.provider.imageSize!.height;

    // Calcula as coordenadas do retângulo (10% de margem em cada lado)
    final double left = width * 0.1;
    final double top = height * 0.1;
    final double right = width * 0.9;
    final double bottom = height * 0.9;

    setState(() {
      // Limpa os pontos existentes
      _polygonPoints.clear();

      // Adiciona os pontos do retângulo
      _polygonPoints.add(Offset(left, top)); // Superior esquerdo
      _polygonPoints.add(Offset(right, top)); // Superior direito
      _polygonPoints.add(Offset(right, bottom)); // Inferior direito
      _polygonPoints.add(Offset(left, bottom)); // Inferior esquerdo

      _initialPolygonCreated = true;
    });
  }

  // Converte coordenadas da tela para coordenadas da imagem original
  Offset _convertToImageCoordinates(Offset screenPosition) {
    if (_imageSize == Size.zero || widget.provider.imageSize == null) {
      return screenPosition;
    }

    try {
      // Obtém a posição global do widget de imagem
      final RenderBox box =
          _imageKey.currentContext?.findRenderObject() as RenderBox;
      final Offset imageGlobalPosition = box.localToGlobal(Offset.zero);
      final Size actualImageSize = box.size;

      // Calcula a posição relativa dentro do widget de imagem
      final Offset localPosition = Offset(
        screenPosition.dx - imageGlobalPosition.dx,
        screenPosition.dy - imageGlobalPosition.dy,
      );

      // Verifica se o toque está dentro da área da imagem
      if (localPosition.dx < 0 ||
          localPosition.dx > actualImageSize.width ||
          localPosition.dy < 0 ||
          localPosition.dy > actualImageSize.height) {
        debugPrint('Toque fora da área da imagem');
        return Offset(
          widget.provider.imageSize!.width / 2,
          widget.provider.imageSize!.height / 2,
        );
      }

      // Calcula as dimensões reais da imagem exibida (considerando BoxFit.contain)
      final double imageAspectRatio =
          widget.provider.imageSize!.width / widget.provider.imageSize!.height;
      final double screenAspectRatio =
          actualImageSize.width / actualImageSize.height;

      double displayWidth, displayHeight;
      double offsetX = 0, offsetY = 0;

      if (imageAspectRatio > screenAspectRatio) {
        // Imagem limitada pela largura
        displayWidth = actualImageSize.width;
        displayHeight = displayWidth / imageAspectRatio;
        offsetY = (actualImageSize.height - displayHeight) / 2;
      } else {
        // Imagem limitada pela altura
        displayHeight = actualImageSize.height;
        displayWidth = displayHeight * imageAspectRatio;
        offsetX = (actualImageSize.width - displayWidth) / 2;
      }

      // Verifica se o toque está dentro da área real da imagem
      if (localPosition.dx < offsetX ||
          localPosition.dx > offsetX + displayWidth ||
          localPosition.dy < offsetY ||
          localPosition.dy > offsetY + displayHeight) {
        debugPrint('Toque fora da área real da imagem');
        return Offset(
          widget.provider.imageSize!.width / 2,
          widget.provider.imageSize!.height / 2,
        );
      }

      // Converte para coordenadas normalizadas (0-1) dentro da imagem exibida
      final double normalizedX = (localPosition.dx - offsetX) / displayWidth;
      final double normalizedY = (localPosition.dy - offsetY) / displayHeight;

      // Converte para coordenadas da imagem original
      return Offset(
        normalizedX * widget.provider.imageSize!.width,
        normalizedY * widget.provider.imageSize!.height,
      );
    } catch (e) {
      debugPrint('Erro ao converter coordenadas: $e');
      return Offset(
        widget.provider.imageSize!.width / 2,
        widget.provider.imageSize!.height / 2,
      );
    }
  }

  // Converte coordenadas da imagem original para coordenadas da tela
  Offset _convertToScreenCoordinates(Offset imagePosition) {
    if (_imageSize == Size.zero || widget.provider.imageSize == null) {
      return imagePosition;
    }

    try {
      // Obtém o tamanho real do widget de imagem
      final RenderBox box =
          _imageKey.currentContext?.findRenderObject() as RenderBox;
      final Offset imageGlobalPosition = box.localToGlobal(Offset.zero);
      final Size actualImageSize = box.size;

      // Calcula as dimensões reais da imagem exibida (considerando BoxFit.contain)
      final double imageAspectRatio =
          widget.provider.imageSize!.width / widget.provider.imageSize!.height;
      final double screenAspectRatio =
          actualImageSize.width / actualImageSize.height;

      double displayWidth, displayHeight;
      double offsetX = 0, offsetY = 0;

      if (imageAspectRatio > screenAspectRatio) {
        // Imagem limitada pela largura
        displayWidth = actualImageSize.width;
        displayHeight = displayWidth / imageAspectRatio;
        offsetY = (actualImageSize.height - displayHeight) / 2;
      } else {
        // Imagem limitada pela altura
        displayHeight = actualImageSize.height;
        displayWidth = displayHeight * imageAspectRatio;
        offsetX = (actualImageSize.width - displayWidth) / 2;
      }

      // Converte para coordenadas normalizadas (0-1) dentro da imagem original
      final double normalizedX =
          imagePosition.dx / widget.provider.imageSize!.width;
      final double normalizedY =
          imagePosition.dy / widget.provider.imageSize!.height;

      // Converte para coordenadas da tela
      final Offset screenPosition = Offset(
        normalizedX * displayWidth + offsetX + imageGlobalPosition.dx,
        normalizedY * displayHeight + offsetY + imageGlobalPosition.dy,
      );

      return screenPosition;
    } catch (e) {
      debugPrint('Erro ao converter coordenadas para tela: $e');
      return Offset.zero;
    }
  }

  // Verifica se um ponto está próximo de um nó existente
  int _getNearbyNodeIndex(Offset screenPosition) {
    for (int i = 0; i < _polygonPoints.length; i++) {
      final Offset screenPoint = _convertToScreenCoordinates(_polygonPoints[i]);
      final double distance = (screenPoint - screenPosition).distance;

      // Aumenta a área de detecção para facilitar o toque
      if (distance <= _nodeSize * 2) {
        debugPrint('Nó encontrado: $i em $screenPoint, distância: $distance');
        return i;
      }
    }
    return -1;
  }

  // Verifica se um ponto está próximo de uma aresta
  int _getNearbyEdgeIndex(Offset screenPosition) {
    if (_polygonPoints.length < 2) return -1;

    for (int i = 0; i < _polygonPoints.length; i++) {
      final int nextIndex = (i + 1) % _polygonPoints.length;
      final Offset p1 = _convertToScreenCoordinates(_polygonPoints[i]);
      final Offset p2 = _convertToScreenCoordinates(_polygonPoints[nextIndex]);

      final double distance = _distanceToLine(screenPosition, p1, p2);
      final bool isOnSegment = _isPointOnLineSegment(screenPosition, p1, p2);

      if (distance <= _edgeDetectionThreshold * 3 && isOnSegment) {
        debugPrint('Aresta encontrada: $i, distância: $distance');
        return i;
      }
    }
    return -1;
  }

  // Calcula a distância de um ponto a uma linha
  double _distanceToLine(Offset point, Offset lineStart, Offset lineEnd) {
    final double lineLength = (lineEnd - lineStart).distance;
    if (lineLength == 0) return (point - lineStart).distance;

    // Fórmula da distância de um ponto a uma linha
    final double t =
        ((point.dx - lineStart.dx) * (lineEnd.dx - lineStart.dx) +
            (point.dy - lineStart.dy) * (lineEnd.dy - lineStart.dy)) /
        (lineLength * lineLength);

    if (t < 0) return (point - lineStart).distance;
    if (t > 1) return (point - lineEnd).distance;

    final Offset projection = Offset(
      lineStart.dx + t * (lineEnd.dx - lineStart.dx),
      lineStart.dy + t * (lineEnd.dy - lineStart.dy),
    );

    return (point - projection).distance;
  }

  // Verifica se um ponto está no segmento de linha
  bool _isPointOnLineSegment(Offset point, Offset lineStart, Offset lineEnd) {
    final double minX =
        math.min(lineStart.dx, lineEnd.dx) - _edgeDetectionThreshold;
    final double maxX =
        math.max(lineStart.dx, lineEnd.dx) + _edgeDetectionThreshold;
    final double minY =
        math.min(lineStart.dy, lineEnd.dy) - _edgeDetectionThreshold;
    final double maxY =
        math.max(lineStart.dy, lineEnd.dy) + _edgeDetectionThreshold;

    return point.dx >= minX &&
        point.dx <= maxX &&
        point.dy >= minY &&
        point.dy <= maxY;
  }

  // Calcula o ponto médio entre dois pontos
  Offset _getMidPoint(Offset p1, Offset p2) {
    return Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
  }

  // Gera a máscara a partir do polígono
  void _generateMaskFromPolygon() {
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos 3 pontos para criar uma máscara'),
        ),
      );
      return;
    }

    try {
      // Converte os pontos do polígono para o formato esperado pelo provider
      widget.provider.clearManualMask();

      // Verifica se as dimensões da imagem estão disponíveis
      if (widget.provider.imageSize == null) {
        debugPrint('Erro: Dimensões da imagem não disponíveis');
        return;
      }

      // Adiciona os pontos ao provider como um único traço
      widget.provider.startNewStroke();

      // Garante que os pontos estejam dentro dos limites da imagem
      for (final point in _polygonPoints) {
        final Offset validPoint = Offset(
          point.dx.clamp(0, widget.provider.imageSize!.width),
          point.dy.clamp(0, widget.provider.imageSize!.height),
        );
        widget.provider.addPointToStroke(validPoint);
      }

      // Adiciona o primeiro ponto novamente para fechar o polígono
      if (_polygonPoints.isNotEmpty) {
        widget.provider.addPointToStroke(_polygonPoints.first);
      }

      // Gera a máscara e conclui a edição
      widget.provider.generatePolygonMask();

      // Exibe mensagem de sucesso
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Máscara gerada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onComplete();
    } catch (e) {
      debugPrint('Erro ao gerar máscara: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar máscara: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Imagem original com key para medir suas dimensões
              Image.file(
                widget.image,
                fit: BoxFit.contain,
                key: _imageKey,
                // Adiciona um callback para quando a imagem for carregada
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (frame != null) {
                    // A imagem foi carregada, atualiza as dimensões
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _updateImageSize();

                        // Se o polígono ainda não foi criado, cria-o
                        if (!_initialPolygonCreated &&
                            widget.provider.imageSize != null) {
                          _createInitialPolygon();
                        }
                      }
                    });
                  }
                  return child;
                },
              ),

              // Desenho do polígono
              if (_polygonPoints.isNotEmpty)
                CustomPaint(
                  painter: _PolygonPainter(
                    points:
                        _polygonPoints
                            .map((p) => _convertToScreenCoordinates(p))
                            .toList(),
                    color: widget.provider.selectedColor.withOpacity(0.5),
                    nodeSize: _nodeSize,
                    selectedNodeIndex: _selectedNodeIndex,
                  ),
                  size: Size.infinite,
                ),

              // Área de interação - DEVE estar por cima de tudo para capturar os toques
              GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                onTapDown: _onTapDown,
                behavior:
                    HitTestBehavior
                        .opaque, // Força a captura de todos os eventos
                child: Container(color: Colors.transparent),
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
                  child: Text(
                    _dragMode
                        ? 'Modo de arrasto: Toque em um nó e arraste para movê-lo'
                        : 'Toque nos nós para selecioná-los. Toque nas arestas para adicionar novos nós.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // Botão de ajuda
              Positioned(
                bottom: 10,
                right: 10,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    _showHelpDialog(context);
                  },
                  child: const Icon(Icons.help_outline),
                ),
              ),

              // Botão para recriar o polígono
              Positioned(
                bottom: 10,
                left: 10,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.orange,
                  onPressed: () {
                    setState(() {
                      _polygonPoints.clear();
                      _initialPolygonCreated = false;
                      _createInitialPolygon();
                    });
                  },
                  child: const Icon(Icons.refresh),
                ),
              ),

              // Indicador de carregamento se o polígono ainda não foi criado
              if (!_initialPolygonCreated)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Inicializando área de seleção...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
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
              // Informação sobre o número de pontos
              Text(
                'Pontos: ${_polygonPoints.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Alternar entre modos de edição
              SwitchListTile(
                title: const Text('Modo de arrasto'),
                subtitle: const Text('Facilita arrastar os nós no emulador'),
                value: _dragMode,
                onChanged: (value) {
                  setState(() {
                    _dragMode = value;
                    // Limpa o nó selecionado ao mudar de modo
                    _selectedNodeIndex = -1;
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),

              // Controle de tamanho do nó
              Row(
                children: [
                  const Text('Tamanho dos nós:'),
                  Expanded(
                    child: Slider(
                      value: _nodeSize,
                      min: 10.0,
                      max: 40.0,
                      divisions: 6,
                      label: _nodeSize.round().toString(),
                      onChanged: (value) {
                        setState(() {
                          _nodeSize = value;
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
                      setState(() {
                        _polygonPoints.clear();
                        _initialPolygonCreated = false;
                        _createInitialPolygon();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reiniciar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _generateMaskFromPolygon,
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

  // Manipula eventos de toque simples
  void _onTapDown(TapDownDetails details) {
    final Offset position = details.globalPosition;
    debugPrint('Tap em: $position');

    // Verifica se o usuário tocou em um nó existente
    final int nodeIndex = _getNearbyNodeIndex(position);
    if (nodeIndex != -1) {
      debugPrint('Nó selecionado: $nodeIndex');

      if (_dragMode) {
        // No modo de arrasto, apenas seleciona o nó
        setState(() {
          _selectedNodeIndex = nodeIndex;
        });
      } else {
        // No modo de edição, mostra o diálogo de ações
        _showNodeActionDialog(context, nodeIndex);
      }
      return;
    }

    // Verifica se o usuário tocou em uma aresta
    final int edgeIndex = _getNearbyEdgeIndex(position);
    if (edgeIndex != -1) {
      debugPrint('Aresta selecionada: $edgeIndex');

      // Adiciona um novo ponto na aresta
      final int nextIndex = (edgeIndex + 1) % _polygonPoints.length;
      final Offset imagePosition = _convertToImageCoordinates(position);

      setState(() {
        _polygonPoints.insert(nextIndex, imagePosition);
        _selectedNodeIndex = nextIndex;
      });
      return;
    }

    debugPrint('Nenhum nó ou aresta encontrado');
  }

  // Mostra um diálogo com ações para um nó
  void _showNodeActionDialog(BuildContext context, int nodeIndex) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Ações do Nó'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Remover Nó'),
                  onTap: () {
                    if (_polygonPoints.length > 3) {
                      setState(() {
                        _polygonPoints.removeAt(nodeIndex);
                        _selectedNodeIndex = -1;
                      });
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'O polígono precisa ter pelo menos 3 pontos',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedNodeIndex = -1;
                  });
                },
                child: const Text('Cancelar'),
              ),
            ],
          ),
    );
  }

  // Mostra um diálogo de ajuda
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Ajuda - Edição Poligonal'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('• Toque nos nós (círculos) para selecioná-los'),
                SizedBox(height: 8),
                Text('• Arraste os nós para ajustar a forma'),
                SizedBox(height: 8),
                Text('• Toque nas arestas (linhas) para adicionar novos nós'),
                SizedBox(height: 8),
                Text('• Selecione um nó para removê-lo'),
                SizedBox(height: 8),
                Text(
                  '• Use o controle deslizante para ajustar o tamanho dos nós',
                ),
                SizedBox(height: 8),
                Text('• Clique em "Concluir" quando terminar'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendi'),
              ),
            ],
          ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    final Offset position = details.globalPosition;
    debugPrint('Pan start em: $position');

    // Tenta encontrar um nó próximo
    final int nodeIndex = _getNearbyNodeIndex(position);
    if (nodeIndex != -1) {
      debugPrint('Iniciando arrasto do nó: $nodeIndex');
      setState(() {
        _dragPointIndex = nodeIndex;
        _selectedNodeIndex = nodeIndex;
      });
    } else {
      debugPrint('Nenhum nó encontrado para arrastar');
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragPointIndex == -1) {
      return;
    }

    final Offset position = details.globalPosition;
    final Offset imagePosition = _convertToImageCoordinates(position);

    debugPrint('Arrastando nó $_dragPointIndex para $imagePosition');

    setState(() {
      _polygonPoints[_dragPointIndex] = Offset(
        imagePosition.dx.clamp(0, widget.provider.imageSize!.width),
        imagePosition.dy.clamp(0, widget.provider.imageSize!.height),
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    debugPrint('Pan end, índice do ponto arrastado: $_dragPointIndex');
    setState(() {
      _dragPointIndex = -1;
    });
  }

  // Adiciona um método para adicionar um novo ponto ao polígono
  void _addNewPoint(Offset position) {
    if (_polygonPoints.isEmpty) {
      _createInitialPolygon();
      return;
    }

    // Converte a posição para coordenadas da imagem
    final Offset imagePosition = _convertToImageCoordinates(position);

    // Encontra o melhor lugar para inserir o novo ponto
    int insertIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < _polygonPoints.length; i++) {
      final int nextIndex = (i + 1) % _polygonPoints.length;
      final Offset p1 = _polygonPoints[i];
      final Offset p2 = _polygonPoints[nextIndex];

      final double distance = _distanceToLineSegment(imagePosition, p1, p2);
      if (distance < minDistance) {
        minDistance = distance;
        insertIndex = nextIndex;
      }
    }

    setState(() {
      _polygonPoints.insert(insertIndex, imagePosition);
    });
  }

  // Calcula a distância de um ponto a um segmento de linha
  double _distanceToLineSegment(
    Offset point,
    Offset lineStart,
    Offset lineEnd,
  ) {
    final double lineLength = (lineEnd - lineStart).distance;
    if (lineLength == 0) return (point - lineStart).distance;

    // Fórmula da distância de um ponto a uma linha
    final double t =
        ((point.dx - lineStart.dx) * (lineEnd.dx - lineStart.dx) +
            (point.dy - lineStart.dy) * (lineEnd.dy - lineStart.dy)) /
        (lineLength * lineLength);

    if (t < 0) return (point - lineStart).distance;
    if (t > 1) return (point - lineEnd).distance;

    final Offset projection = Offset(
      lineStart.dx + t * (lineEnd.dx - lineStart.dx),
      lineStart.dy + t * (lineEnd.dy - lineStart.dy),
    );

    return (point - projection).distance;
  }
}

/// Painter para desenhar o polígono
class _PolygonPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double nodeSize;
  final int selectedNodeIndex;

  _PolygonPainter({
    required this.points,
    required this.color,
    required this.nodeSize,
    required this.selectedNodeIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // Desenha o polígono preenchido com transparência
    final Paint fillPaint =
        Paint()
          ..color = color.withOpacity(0.2)
          ..style = PaintingStyle.fill;

    final Path fillPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      fillPath.lineTo(points[i].dx, points[i].dy);
    }
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Desenha as arestas com linha mais grossa
    final Paint linePaint =
        Paint()
          ..color = color
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length; i++) {
      final int nextIndex = (i + 1) % points.length;
      canvas.drawLine(points[i], points[nextIndex], linePaint);
    }

    // Desenha os nós com efeito de brilho
    for (int i = 0; i < points.length; i++) {
      final bool isSelected = i == selectedNodeIndex;
      final double glowRadius = isSelected ? nodeSize * 1.5 : nodeSize;
      final double nodeRadius = isSelected ? nodeSize * 0.8 : nodeSize * 0.6;

      // Desenha o efeito de brilho
      final Paint glowPaint =
          Paint()
            ..color =
                isSelected
                    ? Colors.yellow.withOpacity(0.3)
                    : color.withOpacity(0.2)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(points[i], glowRadius, glowPaint);

      // Desenha o nó
      final Paint nodeFillPaint =
          Paint()
            ..color = isSelected ? Colors.yellow : Colors.white
            ..style = PaintingStyle.fill;

      final Paint nodeStrokePaint =
          Paint()
            ..color = isSelected ? Colors.orange : color
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 3.0 : 2.0;

      canvas.drawCircle(points[i], nodeRadius, nodeFillPaint);
      canvas.drawCircle(points[i], nodeRadius, nodeStrokePaint);

      // Adiciona um ponto central para melhor visualização
      final Paint centerPaint =
          Paint()
            ..color = isSelected ? Colors.orange : color
            ..style = PaintingStyle.fill;
      canvas.drawCircle(points[i], nodeRadius * 0.3, centerPaint);
    }
  }

  @override
  bool shouldRepaint(_PolygonPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.nodeSize != nodeSize ||
        oldDelegate.selectedNodeIndex != selectedNodeIndex;
  }
}
