import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;
import 'models/player_state.dart';
import 'services/music_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 💻 macOS Desktop 앱 초기 설정 및 투명창/항상위에 배치하기
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(240, 280), // 눅이 창 크기
    backgroundColor: Colors.transparent, // 배경 투명화 필수
    skipTaskbar: true, // 독(Dock)에 안 보이게 숨기기
    alwaysOnTop: true, // 항상 위에 뜨게 하기
    titleBarStyle: TitleBarStyle.hidden, // 타이틀바 숨기기
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setResizable(false);
    await windowManager.setHasShadow(false);
    await windowManager.setVisibleOnAllWorkspaces(true, visibleOnFullScreen: true);
  });

  final playerState = PlayerState();
  final musicService = MusicService(playerState);
  
  musicService.start(interval: const Duration(seconds: 1));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: playerState),
        Provider.value(value: musicService),
      ],
      child: const DJNookApp(),
    ),
  );
}

class DJNookApp extends StatelessWidget {
  const DJNookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent, // 앱 배경 전체를 투명하게
        body: DeskBuddyView(),
      ),
    );
  }
}

class DeskBuddyView extends StatefulWidget {
  const DeskBuddyView({super.key});

  @override
  State<DeskBuddyView> createState() => _DeskBuddyViewState();
}

class _DeskBuddyViewState extends State<DeskBuddyView> with WindowListener {
  Offset? _pointerDownPosition;
  bool _isDragging = false;
  DateTime? _pointerDownTime;
  static const double _dragThreshold = 4.0;

  bool _hasSelectedPlatform = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowDragEnd() {
    _resetDragState();
  }

  void _resetDragState() {
    if (mounted) {
      setState(() {
        _isDragging = false;
        _pointerDownPosition = null;
      });
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownPosition = event.position;
    _isDragging = false;
    _pointerDownTime = DateTime.now();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointerDownPosition == null || _isDragging) return;

    final distance = (event.position - _pointerDownPosition!).distance;
    if (distance > _dragThreshold) {
      _isDragging = true;
      windowManager.startDragging(); // 마우스 드래그로 눅이 이동 가능하게
      Future.delayed(const Duration(milliseconds: 1500), () {
        _resetDragState();
      });
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final clickDuration = _pointerDownTime != null
        ? DateTime.now().difference(_pointerDownTime!)
        : null;

    if (_hasSelectedPlatform && !_isDragging && (clickDuration == null || clickDuration.inMilliseconds < 250)) {
      context.read<MusicService>().togglePlayPause();
    }

    _pointerDownPosition = null;
    _isDragging = false;
  }

  @override
  Widget build(BuildContext context) {
    // 💡 시스템(macOS) 자체의 다크 모드 상태를 감지합니다.
    final isSystemDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

    return SizedBox.expand(
      child: Stack(
        children: [
          // 마우스 드래그 인식 영역
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            child: const SizedBox.expand(),
          ),

          // 플랫폼 선택 전 vs 후 화면 전환
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: !_hasSelectedPlatform
                  ? _buildMacPlatformSelector(isSystemDark)
                  : Stack(
                      children: [
                        // 뒤로가기 화살표
                        Positioned(
                          top: 10,
                          left: 10,
                          child: GestureDetector(
                            onTap: () => setState(() => _hasSelectedPlatform = false),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black26,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_back, color: Colors.white70, size: 14),
                            ),
                          ),
                        ),

                        // ⏪ 이전 곡
                        Positioned(
                          left: 10,
                          top: 125,
                          child: GestureDetector(
                            onTap: () => context.read<MusicService>().previousTrack(),
                            child: _buildHandDrawnButton('assets/images/btn_back.png'),
                          ),
                        ),

                        // ⏩ 다음 곡
                        Positioned(
                          right: 10,
                          top: 125,
                          child: GestureDetector(
                            onTap: () => context.read<MusicService>().nextTrack(),
                            child: _buildHandDrawnButton('assets/images/btn_skip.png'),
                          ),
                        ),

                        // 대왕 춤추는 눅이
                        IgnorePointer(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 20),
                                AnimatedCharacterSection(isDark: isSystemDark), // 다크 모드 상태값 전달
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacPlatformSelector(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select Source',
            style: TextStyle(
              // 💡 다크 모드일 땐 크림색, 라이트 모드일 땐 진한 브라운으로 가독성 확보!
              color: isDark ? const Color(0xFFFFF9E6) : const Color(0xFF4A3525),
              fontFamily: '.SF Pro Rounded',
              fontSize: 13, 
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMacCircleIcon(MusicSource.spotify, Colors.green, Icons.music_note),
              const SizedBox(width: 12),
              _buildMacCircleIcon(MusicSource.appleMusic, Colors.pinkAccent, Icons.apple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacCircleIcon(MusicSource source, Color color, IconData icon) {
    return GestureDetector(
      onTap: () {
        context.read<MusicService>().changeSource(source);
        setState(() => _hasSelectedPlatform = true);
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.6), width: 1.5),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildHandDrawnButton(String imagePath) {
    return Image.asset(
      imagePath,
      width: 32,
      height: 32,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          imagePath.contains('back') ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios,
          color: Colors.white30,
          size: 16,
        );
      },
    );
  }
}

// 🕺 춤추는 눅이 클래스 (스마트 다크/라이트 말풍선 테마!)
class AnimatedCharacterSection extends StatefulWidget {
  final bool isDark; // 다크 모드 여부 받아오기

  const AnimatedCharacterSection({super.key, required this.isDark});

  @override
  State<AnimatedCharacterSection> createState() => _AnimatedCharacterSectionState();
}

class _AnimatedCharacterSectionState extends State<AnimatedCharacterSection> {
  int _currentFrame = 0;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    _animationTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (mounted) {
        setState(() {
          _currentFrame = (_currentFrame + 1) % 4; 
        });
      }
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = context.watch<PlayerState>();
    final isPlaying = playerState.isPlaying;

    final String imagePath = isPlaying
        ? 'assets/images/nook_grooving_$_currentFrame.png'
        : 'assets/images/nook_napping_$_currentFrame.png';

    final String statusText = isPlaying
        ? "🎵  ${playerState.trackName ?? 'Something Good'}"
        : "💤  Napping...";

    // 🌗 밝기에 따른 테마 변수 실시간 계산!
    final Color bubbleColor = widget.isDark 
        ? const Color(0xFF1E1E1E).withOpacity(0.85) // 다크모드: 세련된 딥 다크 그레이
        : const Color(0xFFFFFDF0);                 // 라이트모드: 포근한 우유 크림색

    final Color textColor = widget.isDark 
        ? const Color(0xFFFFF9E6)                 // 다크모드: 따뜻한 크림 아이보리 텍스트
        : const Color(0xFF5C4033);                 // 라이트모드: 진하고 깊은 초콜릿 브라운 텍스트

    final Color borderColor = widget.isDark
        ? const Color(0xFF333333)                 // 다크모드: 은은한 다크 테두리
        : const Color(0xFFE6D5B8);                 // 라이트모드: 아늑한 내추럴 베이지 테두리

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          imagePath,
          width: 140,
          height: 140,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.music_note, color: Colors.black, size: 40),
            );
          },
        ),
        const SizedBox(height: 12),
        // 🌓 주변 환경 밝기(다크/라이트)에 맞춰 슥슥 바뀌는 카멜레온 말풍선
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(widget.isDark ? 0.3 : 0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: textColor,
              fontFamily: '.SF Pro Rounded',
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}