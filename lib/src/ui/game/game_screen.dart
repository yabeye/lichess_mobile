import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartchess/dartchess.dart';
import 'package:chessground/chessground.dart' as cg;

import 'package:lichess_mobile/src/model/game/game_ctrl.dart';
import 'package:lichess_mobile/src/model/game/lobby_game.dart';
import 'package:lichess_mobile/src/model/game/game_status.dart';
import 'package:lichess_mobile/src/model/settings/play_preferences.dart';
import 'package:lichess_mobile/src/ui/settings/toggle_sound_button.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/widgets/adaptive_action_sheet.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/glowing_text.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/widgets/table_board_layout.dart';
import 'package:lichess_mobile/src/widgets/player.dart';
import 'package:lichess_mobile/src/widgets/adaptive_dialog.dart';
import 'package:lichess_mobile/src/utils/immersive_mode.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/chessground_compat.dart';

import 'game_screen_providers.dart';
import 'ping_rating.dart';
import 'game_loader.dart';
import 'status_l10n.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({
    super.key,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with AndroidImmersiveMode {
  @override
  Widget build(BuildContext context) {
    final gameId = ref.watch(lobbyGameProvider);
    final playPrefs = ref.watch(playPreferencesProvider);

    return gameId.when(
      data: (id) {
        final ctrlProvider = gameCtrlProvider(id);
        final gameState = ref.watch(ctrlProvider);
        return gameState.when(
          data: (state) {
            final body = _Body(gameState: state, ctrlProvider: ctrlProvider);
            return PlatformWidget(
              androidBuilder: (context) => _androidBuilder(
                context: context,
                playPrefs: playPrefs,
                body: body,
                gameState: state,
              ),
              iosBuilder: (context) => _iosBuilder(
                context: context,
                playPrefs: playPrefs,
                body: body,
                gameState: state,
              ),
            );
          },
          loading: () => _loadingContent(playPrefs),
          error: (e, s) {
            debugPrint(
              'SEVERE: [GameScreen] could not create game; $e\n$s',
            );
            return _errorContent(playPrefs);
          },
        );
      },
      loading: () => _loadingContent(playPrefs),
      error: (e, s) {
        debugPrint(
          'SEVERE: [GameScreen] could not create game; $e\n$s',
        );
        return _errorContent(playPrefs);
      },
    );
  }

  Widget _loadingContent(PlayPrefs playPrefs) {
    return PlatformWidget(
      androidBuilder: (context) => _androidBuilder(
        context: context,
        playPrefs: playPrefs,
        body: const GameLoader(),
      ),
      iosBuilder: (context) => _iosBuilder(
        context: context,
        playPrefs: playPrefs,
        body: const GameLoader(),
      ),
    );
  }

  Widget _errorContent(PlayPrefs playPrefs) {
    return PlatformWidget(
      androidBuilder: (context) => _androidBuilder(
        context: context,
        playPrefs: playPrefs,
        body: const CreateGameError(),
      ),
      iosBuilder: (context) => _iosBuilder(
        context: context,
        playPrefs: playPrefs,
        body: const CreateGameError(),
      ),
    );
  }

  Widget _androidBuilder({
    required BuildContext context,
    required PlayPrefs playPrefs,
    required Widget body,
    GameCtrlState? gameState,
  }) {
    return Scaffold(
      appBar: AppBar(
        leading: gameState == null || gameState.game.playable == true
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
                child: PingRating(size: 24.0),
              )
            : null,
        title: _GameTitle(playPrefs: playPrefs),
        actions: [
          ToggleSoundButton(),
        ],
      ),
      body: body,
    );
  }

  Widget _iosBuilder({
    required BuildContext context,
    required PlayPrefs playPrefs,
    required Widget body,
    GameCtrlState? gameState,
  }) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        padding: const EdgeInsetsDirectional.only(end: 16.0),
        leading: gameState == null || gameState.game.playable == true
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: PingRating(size: 24.0),
              )
            : null,
        middle: _GameTitle(playPrefs: playPrefs),
        trailing: ToggleSoundButton(),
      ),
      child: body,
    );
  }
}

class _GameTitle extends StatelessWidget {
  const _GameTitle({
    required this.playPrefs,
  });

  final PlayPrefs playPrefs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          playPrefs.speedIcon,
          color: DefaultTextStyle.of(context).style.color,
        ),
        const SizedBox(width: 4.0),
        Text('${playPrefs.timeIncrement.display} • ${context.l10n.rated}'),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.gameState,
    required this.ctrlProvider,
  });

  final GameCtrlState gameState;
  final GameCtrlProvider ctrlProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(ctrlProvider, (prev, state) {
      if (prev?.hasValue == true && state.hasValue) {
        if (prev!.requireValue.game.playable == true &&
            state.requireValue.game.playable == false) {
          showAdaptiveDialog<void>(
            context: context,
            builder: (context) => _GameEndDialog(
              ctrlProvider: ctrlProvider,
            ),
            barrierDismissible: true,
          );
        }

        if (!prev.requireValue.game.canClaimWin &&
            state.requireValue.game.canClaimWin) {
          showAdaptiveDialog<void>(
            context: context,
            builder: (context) => _ClaimWinDialog(
              ctrlProvider: ctrlProvider,
            ),
            barrierDismissible: true,
          );
        }

        if (state.requireValue.redirectGameId != null) {
          // Be sure to pop any dialogs that might be on top of the game screen.
          Navigator.of(context).popUntil((route) => route is! RawDialogRoute);
          ref
              .read(lobbyGameProvider.notifier)
              .rematch(state.requireValue.redirectGameId!);
        }
      }
    });

    final position = gameState.game.positionAt(gameState.stepCursor);
    final sideToMove = position.turn;
    final youAre = gameState.game.youAre ?? Side.white;

    final black = BoardPlayer(
      player: gameState.game.black,
      clock: gameState.game.clock?.black,
      active: gameState.activeClockSide == Side.black,
      materialDiff:
          gameState.game.materialDiffAt(gameState.stepCursor, Side.black),
      timeToMove: sideToMove == Side.black ? gameState.timeToMove : null,
      shouldLinkToUserProfile: youAre != Side.black,
      mePlaying: youAre == Side.black,
      clockEmergencyThreshold:
          youAre == Side.black ? gameState.game.clock?.emergency : null,
    );
    final white = BoardPlayer(
      player: gameState.game.white,
      clock: gameState.game.clock?.white,
      active: gameState.activeClockSide == Side.white,
      materialDiff:
          gameState.game.materialDiffAt(gameState.stepCursor, Side.white),
      timeToMove: sideToMove == Side.white ? gameState.timeToMove : null,
      shouldLinkToUserProfile: youAre != Side.white,
      mePlaying: youAre == Side.white,
      clockEmergencyThreshold:
          youAre == Side.white ? gameState.game.clock?.emergency : null,
    );

    final topPlayer = youAre == Side.white ? black : white;
    final bottomPlayer = youAre == Side.white ? white : black;
    final isBoardTurned = ref.watch(isBoardTurnedProvider);

    final content = Column(
      children: [
        Expanded(
          child: SafeArea(
            bottom: false,
            child: TableBoardLayout(
              boardData: cg.BoardData(
                interactableSide:
                    gameState.game.playable && !gameState.isReplaying
                        ? youAre == Side.white
                            ? cg.InteractableSide.white
                            : cg.InteractableSide.black
                        : cg.InteractableSide.none,
                orientation: isBoardTurned ? youAre.opposite.cg : youAre.cg,
                fen: position.fen,
                lastMove: gameState.game.moveAt(gameState.stepCursor)?.cg,
                isCheck: position.isCheck,
                sideToMove: sideToMove.cg,
                validMoves: algebraicLegalMoves(position),
                onMove: (move, {isPremove}) {
                  ref
                      .read(ctrlProvider.notifier)
                      .onUserMove(Move.fromUci(move.uci)!);
                },
              ),
              topTable: topPlayer,
              bottomTable: gameState.canShowClaimWinCountdown &&
                      gameState.opponentLeftCountdown != null
                  ? _ClaimWinCountdown(
                      duration: gameState.opponentLeftCountdown!,
                    )
                  : bottomPlayer,
              moves: gameState.game.steps
                  .skip(1)
                  .map((e) => e.sanMove!.san)
                  .toList(growable: false),
              currentMoveIndex: gameState.stepCursor,
              onSelectMove: (moveIndex) {
                ref.read(ctrlProvider.notifier).cursorAt(moveIndex);
              },
            ),
          ),
        ),
        _GameBottomBar(gameState: gameState, ctrlProvider: ctrlProvider),
      ],
    );

    return gameState.game.playable
        ? WillPopScope(
            onWillPop: () async => false,
            child: content,
          )
        : content;
  }
}

class _GameBottomBar extends ConsumerWidget {
  const _GameBottomBar({
    required this.gameState,
    required this.ctrlProvider,
  });

  final GameCtrlState gameState;
  final GameCtrlProvider ctrlProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: Styles.horizontalBodyPadding,
      color: defaultTargetPlatform == TargetPlatform.iOS
          ? CupertinoTheme.of(context).barBackgroundColor
          : Theme.of(context).bottomAppBarTheme.color,
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            BottomBarButton(
              label: context.l10n.menu,
              shortLabel: context.l10n.menu,
              onTap: () {
                _showGameMenu(context, ref);
              },
              icon: Icons.menu,
            ),
            const SizedBox(
              width: 44.0,
            ),
            const SizedBox(
              width: 44.0,
            ),
            RepeatButton(
              onLongPress:
                  gameState.canGoBackward ? () => _moveBackward(ref) : null,
              child: BottomBarButton(
                onTap:
                    gameState.canGoBackward ? () => _moveBackward(ref) : null,
                label: 'Previous',
                shortLabel: 'Previous',
                icon: CupertinoIcons.chevron_back,
              ),
            ),
            RepeatButton(
              onLongPress: gameState.canGoForward
                  ? () => _moveForward(ref, hapticFeedback: false)
                  : null,
              child: BottomBarButton(
                onTap: gameState.canGoForward ? () => _moveForward(ref) : null,
                label: context.l10n.next,
                shortLabel: context.l10n.next,
                icon: CupertinoIcons.chevron_forward,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _moveForward(WidgetRef ref, {bool hapticFeedback = true}) {
    ref
        .read(ctrlProvider.notifier)
        .cursorForward(hapticFeedback: hapticFeedback);
  }

  void _moveBackward(WidgetRef ref) {
    ref.read(ctrlProvider.notifier).cursorBackward();
  }

  Future<void> _showGameMenu(BuildContext context, WidgetRef ref) {
    return showAdaptiveActionSheet(
      context: context,
      actions: [
        BottomSheetAction(
          leading: const Icon(Icons.swap_vert),
          label: Text(context.l10n.flipBoard),
          onPressed: (context) {
            ref.read(isBoardTurnedProvider.notifier).toggle();
          },
        ),
        if (gameState.game.abortable)
          BottomSheetAction(
            leading: const Icon(Icons.cancel),
            label: Text(context.l10n.abortGame),
            onPressed: (context) {
              ref.read(ctrlProvider.notifier).abortGame();
            },
          ),
        if (gameState.game.resignable)
          BottomSheetAction(
            leading: const Icon(Icons.flag),
            label: Text(context.l10n.resign),
            dismissOnPress: false,
            onPressed: (context) async {
              await Navigator.of(context).maybePop();
              if (context.mounted) {
                final result = await showAdaptiveDialog<bool>(
                  context: context,
                  builder: (context) => YesNoDialog(
                    title: const Text('Are you sure?'),
                    content: Text(context.l10n.resignTheGame),
                    onYes: () {
                      return Navigator.of(context).pop(true);
                    },
                    onNo: () => Navigator.of(context).pop(false),
                  ),
                );
                if (result == true) {
                  ref.read(ctrlProvider.notifier).resignGame();
                }
              }
            },
          ),
        if (gameState.game.canClaimWin) ...[
          BottomSheetAction(
            label: Text(context.l10n.forceDraw),
            dismissOnPress: true,
            onPressed: (context) {
              ref.read(ctrlProvider.notifier).forceDraw();
            },
          ),
          BottomSheetAction(
            label: Text(context.l10n.forceResignation),
            dismissOnPress: true,
            onPressed: (context) {
              ref.read(ctrlProvider.notifier).forceResign();
            },
          ),
        ],
        if (gameState.game.player?.offeringRematch == true)
          BottomSheetAction(
            label: Text(context.l10n.cancelRematchOffer),
            dismissOnPress: true,
            isDestructiveAction: true,
            onPressed: (context) {
              ref.read(ctrlProvider.notifier).declineRematch();
            },
          )
        else if (gameState.canOfferRematch &&
            gameState.game.opponent?.onGame == true)
          BottomSheetAction(
            label: Text(context.l10n.rematch),
            dismissOnPress: true,
            onPressed: (context) {
              ref.read(ctrlProvider.notifier).proposeOrAcceptRematch();
            },
          ),
        if (gameState.canGetNewOpponent)
          BottomSheetAction(
            label: Text(context.l10n.newOpponent),
            onPressed: (_) {
              ref.read(lobbyGameProvider.notifier).newOpponent();
            },
          ),
      ],
    );
  }
}

class _GameEndDialog extends ConsumerStatefulWidget {
  const _GameEndDialog({
    required this.ctrlProvider,
  });

  final GameCtrlProvider ctrlProvider;

  @override
  ConsumerState<_GameEndDialog> createState() => _GameEndDialogState();
}

class _GameEndDialogState extends ConsumerState<_GameEndDialog> {
  late Timer _buttonActivationTimer;
  bool _activateButtons = false;

  @override
  void initState() {
    _buttonActivationTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _activateButtons = true;
        });
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _buttonActivationTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(widget.ctrlProvider).requireValue;

    final showWinner = gameState.game.winner != null
        ? ' • ${gameState.game.winner == Side.white ? context.l10n.whiteIsVictorious : context.l10n.blackIsVictorious}'
        : '';

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (gameState.game.status.value >= GameStatus.mate.value)
          Text(
            gameState.game.winner == null
                ? '½-½'
                : gameState.game.winner == Side.white
                    ? '1-0'
                    : '0-1',
            style: const TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        const SizedBox(height: 6.0),
        Text(
          '${gameStatusL10n(context, gameState)}$showWinner',
          style: const TextStyle(
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 24.0),
        if (gameState.game.player?.offeringRematch == true)
          SecondaryButton(
            semanticsLabel: context.l10n.cancelRematchOffer,
            onPressed: () {
              ref.read(widget.ctrlProvider.notifier).declineRematch();
            },
            child: Text(context.l10n.cancelRematchOffer),
          )
        else if (gameState.canOfferRematch)
          SecondaryButton(
            semanticsLabel: context.l10n.rematch,
            onPressed:
                _activateButtons && gameState.game.opponent?.onGame == true
                    ? () {
                        ref
                            .read(widget.ctrlProvider.notifier)
                            .proposeOrAcceptRematch();
                      }
                    : null,
            child: gameState.game.opponent?.offeringRematch == true
                ? GlowingText(
                    context.l10n.rematch,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  )
                : Text(context.l10n.rematch),
          ),
        const SizedBox(height: 8.0),
        SecondaryButton(
          semanticsLabel: context.l10n.newOpponent,
          onPressed: _activateButtons
              ? () {
                  ref.read(lobbyGameProvider.notifier).newOpponent();
                  // Other alert dialogs may be shown before this one, so be sure to pop them all
                  Navigator.of(context)
                      .popUntil((route) => route is! RawDialogRoute);
                }
              : null,
          child: Text(context.l10n.newOpponent),
        ),
      ],
    );

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return CupertinoAlertDialog(
        content: content,
      );
    } else {
      return Dialog(
        child: content,
      );
    }
  }
}

class _ClaimWinDialog extends ConsumerWidget {
  const _ClaimWinDialog({
    required this.ctrlProvider,
  });

  final GameCtrlProvider ctrlProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(ctrlProvider).requireValue;

    final content = Text(context.l10n.opponentLeftChoices);

    void onClaimWin() {
      Navigator.of(context).pop();
      ref.read(ctrlProvider.notifier).forceResign();
    }

    void onClaimDraw() {
      Navigator.of(context).pop();
      ref.read(ctrlProvider.notifier).forceDraw();
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return CupertinoAlertDialog(
        content: content,
        actions: [
          CupertinoDialogAction(
            onPressed: gameState.game.canClaimWin ? onClaimWin : null,
            child: Text(context.l10n.forceResignation),
          ),
          CupertinoDialogAction(
            onPressed: gameState.game.canClaimWin ? onClaimDraw : null,
            child: Text(context.l10n.forceDraw),
          ),
        ],
      );
    } else {
      return AlertDialog(
        content: content,
        actions: [
          TextButton(
            onPressed: gameState.game.canClaimWin ? onClaimWin : null,
            child: Text(context.l10n.forceResignation),
          ),
          TextButton(
            onPressed: gameState.game.canClaimWin ? onClaimDraw : null,
            child: Text(context.l10n.forceDraw),
          ),
        ],
      );
    }
  }
}

class _ClaimWinCountdown extends StatelessWidget {
  const _ClaimWinCountdown({
    required this.duration,
  });

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final secs = duration.inSeconds.remainder(60);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Text(context.l10n.opponentLeftCounter(secs)),
      ),
    );
  }
}
