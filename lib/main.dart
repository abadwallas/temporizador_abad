import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Timer de Round',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const RoundTimerPage(),
    );
  }
}

class RoundTimerPage extends StatefulWidget {
  const RoundTimerPage({super.key});
  @override
  State<RoundTimerPage> createState() => _RoundTimerPageState();
}

class _RoundTimerPageState extends State<RoundTimerPage> {
  // ===== Configurações =====
  Duration roundDuration = const Duration(seconds: 10);
  Duration restDuration = const Duration(seconds: 5);
  int totalRounds = 3; // 🔢 total de rounds
  final int warningSeconds = 10; // ⚠️ pré-sinal a 10s do fim do ROUND

  // ===== Estado =====
  int tempoRestante = 0; // em segundos
  bool isRound = true; // true=round, false=descanso
  bool isRunning = false;
  bool isPaused = false;
  int currentRound = 1; // round atual (1..totalRounds)
  Timer? timer;
  final player = AudioPlayer();

  // ===== Helpers =====
  String _fmt2(int n) => n.toString().padLeft(2, '0');
  String _fmtClock(int totalSeconds) =>
      '${_fmt2(totalSeconds ~/ 60)}:${_fmt2(totalSeconds % 60)}';

  Future<Duration?> _pickDuration({
    required Duration initial,
    required String title,
  }) async {
    Duration temp = initial;
    return showModalBottomSheet<Duration>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, temp),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.ms,
                    initialTimerDuration: initial,
                    onTimerDurationChanged: (d) => temp = d,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<int?> _pickRounds(int initial) async {
    int temp = initial.clamp(1, 99);
    return showModalBottomSheet<int>(
      context: context,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: 250,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Total de rounds',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(
                    initialItem: temp - 1,
                  ),
                  onSelectedItemChanged: (i) => temp = i + 1,
                  children: List.generate(
                    99,
                    (i) => Center(child: Text('${i + 1}')),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, temp),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Controle =====
  void _startTimer() {
    if (roundDuration.inSeconds <= 0 || restDuration.inSeconds <= 0) return;

    timer?.cancel();
    setState(() {
      isRound = true;
      isRunning = true;
      isPaused = false;
      currentRound = 1;
      tempoRestante = roundDuration.inSeconds;
    });

    player.play(AssetSource("start_round.mp3"));
    timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer t) async {
    if (tempoRestante > 0) {
      setState(() => tempoRestante--);

      // ⚠️ pré-sinal a 10s do fim do ROUND
      if (isRound &&
          roundDuration.inSeconds > warningSeconds &&
          tempoRestante == warningSeconds) {
        await player.play(AssetSource("warning.mp3")).catchError((_) async {
          await player.play(AssetSource("beep.mp3"));
        });
      }

      // 🔔 bip nos últimos 3s (round e descanso)
      if (tempoRestante <= 3 && tempoRestante > 0) {
        player.play(AssetSource("beep.mp3"));
      }

      // 🚨 fim do período (bateu zero agora)
      if (tempoRestante == 0) {
        player.play(AssetSource("start_round.mp3"));
      }
      return;
    }

    // ===== Chegou a 0: alterna período OU finaliza =====
    if (isRound) {
      // terminou um round
      if (currentRound >= totalRounds) {
        // ✅ acabou a série inteira: para sem descanso final
        _stopAndReset();
        return;
      } else {
        // vai para descanso
        setState(() {
          isRound = false;
          tempoRestante = restDuration.inSeconds;
        });
        //player.play(AssetSource("start_round.mp3"));//removido para não tocar descanso
      }
    } else {
      // terminou descanso -> próximo round
      setState(() {
        isRound = true;
        currentRound++;
        tempoRestante = roundDuration.inSeconds;
      });
      player.play(AssetSource("start_round.mp3"));
    }
  }

  void _pauseOrResume() {
    if (!isRunning) return;
    if (isPaused) {
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), _onTick);
      setState(() => isPaused = false);
    } else {
      timer?.cancel();
      setState(() => isPaused = true);
    }
  }

  void _stopAndReset() {
    timer?.cancel();
    setState(() {
      isRunning = false;
      isPaused = false;
      tempoRestante = 0;
      // mantém isRound e currentRound como estão
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    player.dispose();
    super.dispose();
  }

  // ====== Layout responsivo para os seletores ======
  Widget _buildPickersResponsive(BoxConstraints c) {
    const breakpoint = 520.0; // largura a partir da qual fica lado a lado
    final isWide = c.maxWidth >= breakpoint;

    final roundTile = _TimeTile(
      title: 'Tempo do round',
      value: _fmtClock(roundDuration.inSeconds),
      onTap: () async {
        final d = await _pickDuration(
          initial: roundDuration,
          title: 'Tempo do round',
        );
        if (d != null) {
          setState(() => roundDuration = d);
          if (!isRunning && isRound) tempoRestante = roundDuration.inSeconds;
        }
      },
    );

    final restTile = _TimeTile(
      title: 'Tempo de descanso',
      value: _fmtClock(restDuration.inSeconds),
      onTap: () async {
        final d = await _pickDuration(
          initial: restDuration,
          title: 'Tempo de descanso',
        );
        if (d != null) setState(() => restDuration = d);
      },
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: roundTile),
          const SizedBox(width: 12),
          Expanded(child: restTile),
        ],
      );
    } else {
      return Column(
        children: [roundTile, const SizedBox(height: 12), restTile],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelPeriodo = isRound ? "🏆 Round" : "💤 Descanso";
    final labelRound = "$currentRound/$totalRounds";

    final totalAtual = (isRound ? roundDuration : restDuration).inSeconds;
    final tempoDisplay = isRunning
        ? _fmtClock(tempoRestante)
        : _fmtClock(totalAtual);

    // Barra que esvazia (1.0 cheio -> 0.0 vazio)
    final double progress = totalAtual == 0 ? 0.0 : tempoRestante / totalAtual;

    return Scaffold(
      appBar: AppBar(title: const Text("Timer de Round")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape =
              MediaQuery.of(context).orientation == Orientation.landscape;
          final labelPeriodo = isRound ? "🏆 Round" : "💤 Descanso";
          final labelRound = "$currentRound/$totalRounds";
          final totalAtual = (isRound ? roundDuration : restDuration).inSeconds;
          final tempoDisplay = isRunning
              ? _fmtClock(tempoRestante)
              : _fmtClock(totalAtual);
          final double progress = totalAtual == 0
              ? 0.0
              : tempoRestante / totalAtual;

          // conteúdo principal (sem botões)
          final content = Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min, // permite encolher
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: isLandscape ? 8 : 16),

                _buildPickersResponsive(constraints),
                SizedBox(height: isLandscape ? 8 : 12),

                _ValueTile(
                  title: 'Total de rounds',
                  value: '$totalRounds',
                  onTap: () async {
                    final r = await _pickRounds(totalRounds);
                    if (r != null) setState(() => totalRounds = r);
                  },
                ),
                SizedBox(height: isLandscape ? 16 : 24),

                Text(
                  '$labelPeriodo — Round $labelRound',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isLandscape ? 6 : 8),

                // Barra que esvazia (animada)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: progress, end: progress),
                    duration: const Duration(milliseconds: 350),
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value.clamp(0.0, 1.0),
                      minHeight: 14,
                      color: isRound ? Colors.blue : Colors.orange,
                      backgroundColor: Colors.black12,
                    ),
                  ),
                ),
                SizedBox(height: isLandscape ? 6 : 8),

                // Relógio grande que reduz se faltar espaço
                Flexible(
                  // <- dá flexibilidade vertical
                  child: SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tempoDisplay,
                        style: TextStyle(
                          fontSize: isLandscape ? 42 : 120, // menor no paisagem
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  height: isLandscape ? 8 : 12,
                ), // respiro antes do rodapé
              ],
            ),
          );

          // Em paisagem, deixa rolável; em retrato, normal
          return isLandscape ? SingleChildScrollView(child: content) : content;
        },
      ),

      // Botões fixos no rodapé
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.of(context).orientation == Orientation.portrait
                ? 40
                : 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: (){
                    if(isRunning){
                      _startTimer();
                    }else{
                      _startTimer();
                    }
                  },
                  child: Icon(isRunning ? Icons.restart_alt : Icons.play_arrow, size: 48),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isRunning ? _pauseOrResume : null,
                  child: Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 48),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _stopAndReset,
                  child: const Icon(Icons.stop, size: 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Widgets utilitários =====
class _TimeTile extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;

  const _TimeTile({
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity, // para empilhado ocupar 100%
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // título com fonte menor + ellipsis para prevenir overflow
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: false,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;

  const _ValueTile({
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: false,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
