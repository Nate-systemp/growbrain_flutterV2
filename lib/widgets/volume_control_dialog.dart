import 'package:flutter/material.dart';

class VolumeControlDialog extends StatefulWidget {
  final double initialBackgroundMusicVolume;
  final double initialSoundEffectsVolume;
  final Function(double) onBackgroundMusicVolumeChanged;
  final Function(double) onSoundEffectsVolumeChanged;

  const VolumeControlDialog({
    Key? key,
    required this.initialBackgroundMusicVolume,
    required this.initialSoundEffectsVolume,
    required this.onBackgroundMusicVolumeChanged,
    required this.onSoundEffectsVolumeChanged,
  }) : super(key: key);

  @override
  State<VolumeControlDialog> createState() => _VolumeControlDialogState();
}

class _VolumeControlDialogState extends State<VolumeControlDialog> {
  late double _backgroundMusicVolume;
  late double _soundEffectsVolume;

  @override
  void initState() {
    super.initState();
    _backgroundMusicVolume = widget.initialBackgroundMusicVolume;
    _soundEffectsVolume = widget.initialSoundEffectsVolume;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Volume Control',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Background Music Volume
            _buildVolumeControl(
              icon: Icons.music_note,
              title: 'Background Music',
              volume: _backgroundMusicVolume,
              onChanged: (value) {
                setState(() {
                  _backgroundMusicVolume = value;
                });
                widget.onBackgroundMusicVolumeChanged(value);
              },
            ),
            
            const SizedBox(height: 24),
            
            // Sound Effects Volume
            _buildVolumeControl(
              icon: Icons.volume_up,
              title: 'Sound Effects & Voice',
              volume: _soundEffectsVolume,
              onChanged: (value) {
                setState(() {
                  _soundEffectsVolume = value;
                });
                widget.onSoundEffectsVolumeChanged(value);
              },
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeControl({
    required IconData icon,
    required String title,
    required double volume,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: volume > 0 ? const Color(0xFF5B6F4A) : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ),
            Text(
              '${(volume * 100).round()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5B6F4A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey[100],
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
              activeTrackColor: const Color(0xFF5B6F4A),
              inactiveTrackColor: Colors.grey[300],
              thumbColor: const Color(0xFF5B6F4A),
              overlayColor: const Color(0xFF5B6F4A).withOpacity(0.2),
            ),
            child: Slider(
              value: volume,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
