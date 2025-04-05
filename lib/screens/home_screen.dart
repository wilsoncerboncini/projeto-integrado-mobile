import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wall_paint_provider.dart';
import '../widgets/image_preview_widget.dart';
import '../widgets/color_picker_widget.dart';
import '../widgets/tolerance_slider_widget.dart';
import '../widgets/mask_editor_widget.dart';
import '../widgets/polygon_mask_editor_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 30,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.home_outlined, color: Colors.white);
              },
            ),
            const SizedBox(width: 8),
            const Text(
              'THE WALL PINTURAS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Consumer<WallPaintProvider>(
            builder: (context, provider, _) {
              if (provider.hasImage) {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => provider.clearData(),
                  tooltip: 'Limpar',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<WallPaintProvider>(
        builder: (context, provider, _) {
          return Stack(
            children: [
              // Conteúdo principal
              if (provider.manualMaskMode && provider.hasImage)
                // Editor de máscara
                provider.usePolygonMaskEditor
                    ? PolygonMaskEditorWidget(
                      image: provider.originalImage!,
                      provider: provider,
                      onComplete: () {
                        provider.toggleManualMaskMode(false);
                        provider.applyColorToWall();
                      },
                    )
                    : MaskEditorWidget(
                      image: provider.originalImage!,
                      provider: provider,
                      onComplete: () {
                        provider.toggleManualMaskMode(false);
                        provider.applyColorToWall();
                      },
                    )
              else
                // Conteúdo normal
                _buildMainContent(context, provider),

              // Indicador de carregamento
              if (provider.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, WallPaintProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Exibe a imagem modificada se existir, caso contrário exibe a original
          ImagePreviewWidget(
            image:
                provider.hasModifiedImage
                    ? provider.modifiedImage
                    : provider.originalImage,
            placeholder: 'Selecione ou tire uma foto para começar',
            height: 350,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 24),

          // Se não houver imagem, exibe os botões para selecionar ou tirar foto
          if (!provider.hasImage)
            _buildImageSelectionButtons(context, provider)
          else
            _buildImageEditingTools(context, provider),
        ],
      ),
    );
  }

  Widget _buildImageSelectionButtons(
    BuildContext context,
    WallPaintProvider provider,
  ) {
    return Column(
      children: [
        const Text(
          'Selecione uma imagem para começar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => provider.captureImageFromCamera(),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Câmera'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => provider.pickImageFromGallery(),
                icon: const Icon(Icons.photo_library),
                label: const Text('Galeria'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageEditingTools(
    BuildContext context,
    WallPaintProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Seletor de cor
        ColorPickerWidget(
          currentColor: provider.selectedColor,
          onColorChanged: (color) => provider.updateSelectedColor(color),
        ),
        const SizedBox(height: 24),

        // Slider de tolerância
        ToleranceSliderWidget(
          value: provider.colorTolerance,
          onChanged: (value) => provider.updateColorTolerance(value),
        ),
        const SizedBox(height: 16),

        // Slider de opacidade
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Opacidade:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${provider.colorOpacity.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Theme.of(context).primaryColor,
                inactiveTrackColor: Colors.grey.shade300,
                thumbColor: Theme.of(context).primaryColor,
                overlayColor: Theme.of(context).primaryColor.withOpacity(0.2),
                trackHeight: 4.0,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 12.0,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 24.0,
                ),
              ),
              child: Slider(
                value: provider.colorOpacity,
                min: 10.0,
                max: 100.0,
                divisions: 9,
                onChanged: (value) => provider.updateColorOpacity(value),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transparente',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Text(
                  'Sólido',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Opções avançadas
        Card(
          elevation: 0,
          color: Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Opções avançadas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Alternar entre modos de detecção
                SwitchListTile(
                  title: const Text('Detecção avançada de paredes'),
                  subtitle: const Text(
                    'Usa algoritmos mais precisos para identificar paredes',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: provider.advancedDetection,
                  onChanged: (value) => provider.toggleAdvancedDetection(value),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),

                // Opções de edição manual da máscara
                ExpansionTile(
                  title: const Text('Edição manual da máscara'),
                  subtitle: const Text(
                    'Selecione a área onde deseja aplicar a cor',
                    style: TextStyle(fontSize: 12),
                  ),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(left: 16, bottom: 8),
                  children: [
                    // Opção de seleção poligonal
                    ListTile(
                      title: const Text('Seleção poligonal'),
                      subtitle: const Text(
                        'Crie um polígono ajustável para selecionar a área',
                        style: TextStyle(fontSize: 12),
                      ),
                      leading: Radio<bool>(
                        value: true,
                        groupValue: provider.usePolygonMaskEditor,
                        onChanged:
                            (value) => provider.togglePolygonMaskEditor(true),
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),

                    // Opção de pintura livre
                    ListTile(
                      title: const Text('Pintura livre'),
                      subtitle: const Text(
                        'Pinte manualmente as áreas onde deseja aplicar a cor',
                        style: TextStyle(fontSize: 12),
                      ),
                      leading: Radio<bool>(
                        value: false,
                        groupValue: provider.usePolygonMaskEditor,
                        onChanged:
                            (value) => provider.togglePolygonMaskEditor(false),
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),

                    // Botão para iniciar a edição
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ElevatedButton(
                        onPressed: () => provider.toggleManualMaskMode(true),
                        child: const Text('Iniciar Edição Manual'),
                      ),
                    ),
                  ],
                ),

                // Visualizar máscara (se disponível)
                if (provider.hasWallMask)
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Máscara de Detecção'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Áreas brancas mostram onde a cor será aplicada:',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  Image.file(
                                    provider.wallMask!,
                                    height: 300,
                                    fit: BoxFit.contain,
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Fechar'),
                                ),
                              ],
                            ),
                      );
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('Visualizar Máscara de Detecção'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Botão para ajustar a tolerância automaticamente
        OutlinedButton.icon(
          onPressed: () {
            // Valores recomendados para diferentes tipos de paredes
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Ajuste Automático'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Selecione o tipo de parede:'),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('Parede Lisa'),
                          subtitle: const Text('Tolerância baixa (20%)'),
                          onTap: () {
                            provider.updateColorTolerance(20);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: const Text('Parede Texturizada'),
                          subtitle: const Text('Tolerância média (40%)'),
                          onTap: () {
                            provider.updateColorTolerance(40);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: const Text('Parede com Variações'),
                          subtitle: const Text('Tolerância alta (60%)'),
                          onTap: () {
                            provider.updateColorTolerance(60);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
            );
          },
          icon: const Icon(Icons.auto_fix_high),
          label: const Text('Ajuste Automático'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 24),

        // Botão para aplicar a cor
        ElevatedButton.icon(
          onPressed: () => provider.applyColorToWall(),
          icon: const Icon(Icons.format_paint),
          label: const Text('Aplicar Cor'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Botão para desfazer as alterações
        if (provider.hasModifiedImage)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: () {
                provider.clearModifiedImage();
              },
              icon: const Icon(Icons.undo),
              label: const Text('Desfazer Alterações'),
            ),
          ),

        const SizedBox(height: 16),

        // Botões para selecionar nova imagem
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => provider.captureImageFromCamera(),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Nova Foto'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => provider.pickImageFromGallery(),
                icon: const Icon(Icons.photo_library),
                label: const Text('Nova Imagem'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
