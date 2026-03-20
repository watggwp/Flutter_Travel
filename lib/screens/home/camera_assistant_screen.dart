import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_translations.dart';

class CameraAssistantScreen extends StatefulWidget {
  final XFile initialImage;
  const CameraAssistantScreen({super.key, required this.initialImage});

  @override
  State<CameraAssistantScreen> createState() => _CameraAssistantScreenState();
}

class _CameraAssistantScreenState extends State<CameraAssistantScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isLoading = true;
  bool _isSpeaking = false;
  String _aiResponse = "";
  Uint8List? _imageBytes;
  
  @override
  void initState() {
    super.initState();
    _loadImage();
    _analyzeImage();
    _initTts();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.initialImage.readAsBytes();
    if (mounted) setState(() => _imageBytes = bytes);
  }

  void _initTts() async {
    await _flutterTts.setLanguage(AppTranslations.currentLanguage.value == 'th' ? 'th-TH' : AppTranslations.currentLanguage.value == 'ja' ? 'ja-JP' : 'en-US');
    _flutterTts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  Future<void> _analyzeImage() async {
    try {
      // 1. Get Location
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      Position? position;
      if (permission != LocationPermission.deniedForever) {
        position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      }

      // 2. Prepare Image
      final bytes = await widget.initialImage.readAsBytes();
      final base64Image = base64Encode(bytes);

      // 3. Call Backend
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      final response = await http.post(
        Uri.parse(AuthService.baseUrl.replaceFirst('/auth', '/ai/identify')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'image': base64Image,
          'lat': position?.latitude ?? 0.0,
          'lng': position?.longitude ?? 0.0,
          'lang': AppTranslations.currentLanguage.value,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _aiResponse = jsonDecode(response.body)['result'];
          _isLoading = false;
        });
      } else {
        throw Exception("Failed to identify");
      }
    } catch (e) {
      setState(() {
        _aiResponse = AppTranslations.get('ai_error');
        _isLoading = false;
      });
    }
  }

  Future<void> _speak() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    } else {
      if (_aiResponse.isNotEmpty) {
        setState(() => _isSpeaking = true);
        // Strip markdown for cleaner speech
        String plainText = _aiResponse.replaceAll(RegExp(r'[*#_]'), '');
        await _flutterTts.speak(plainText);
      }
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Captured Image
          Positioned.fill(
            child: Opacity(
              opacity: 0.5,
              child: _imageBytes != null
                  ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                  : const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            ),
          ),
          
          // Content
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                      ),
                      Text(
                        AppTranslations.get('ai_title'),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 48), // Spacer
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // AI Result Card
                Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  _isLoading ? AppTranslations.get('ai_analyzing') : AppTranslations.get('ai_suggestion'),
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (!_isLoading)
                            IconButton(
                              onPressed: _speak,
                              icon: Icon(
                                _isSpeaking ? Icons.stop_circle : Icons.volume_up_rounded,
                                color: AppColors.primary,
                                size: 32,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : SingleChildScrollView(
                                child: MarkdownBody(
                                  data: _aiResponse,
                                  styleSheet: MarkdownStyleSheet(
                                    p: const TextStyle(fontSize: 16, height: 1.5, color: AppColors.textPrimary),
                                    h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 2.0),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
