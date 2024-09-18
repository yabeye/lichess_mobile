import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lichess_mobile/src/model/auth/auth_session.dart';
import 'package:lichess_mobile/src/model/challenge/challenge.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/common/speed.dart';
import 'package:lichess_mobile/src/model/lobby/correspondence_challenge.dart';
import 'package:lichess_mobile/src/model/user/user.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/widgets/adaptive_action_sheet.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/user_full_name.dart';

class ChallengeListItem extends ConsumerWidget {
  const ChallengeListItem({
    super.key,
    required this.challenge,
    required this.user,
    this.onPressed,
    this.onAccept,
    this.onDecline,
    this.onCancel,
  });

  final Challenge challenge;
  final LightUser user;
  final VoidCallback? onPressed;
  final VoidCallback? onAccept;
  final VoidCallback? onCancel;
  final void Function(ChallengeDeclineReason reason)? onDecline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authSessionProvider)?.user;
    final isMyChallenge = me != null && me.id == user.id;

    final color = isMyChallenge
        ? context.lichessColors.good.withValues(alpha: 0.2)
        : null;

    return Container(
      color: color,
      child: Slidable(
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.6,
          children: [
            if (onAccept != null)
              SlidableAction(
                icon: Icons.check,
                onPressed: (_) => onAccept!(),
                spacing: 8.0,
                backgroundColor: context.lichessColors.good,
                foregroundColor: Colors.white,
                label: context.l10n.accept,
              ),
            if (onDecline != null || (isMyChallenge && onCancel != null))
              SlidableAction(
                icon: Icons.close,
                onPressed:
                    isMyChallenge ? (_) => onCancel!() : _showDeclineReasons,
                spacing: 8.0,
                backgroundColor: context.lichessColors.error,
                foregroundColor: Colors.white,
                label:
                    isMyChallenge ? context.l10n.cancel : context.l10n.decline,
              ),
          ],
        ),
        child: PlatformListTile(
          padding: Styles.bodyPadding,
          leading: Icon(challenge.perf.icon, size: 36),
          trailing: challenge.challenger?.lagRating != null
              ? LagIndicator(lagRating: challenge.challenger!.lagRating!)
              : null,
          title: isMyChallenge
              ? UserFullNameWidget(
                  user: challenge.destUser != null
                      ? challenge.destUser!.user
                      : user,
                )
              : UserFullNameWidget(
                  user: user,
                  rating: challenge.challenger?.rating,
                ),
          subtitle: Text(challenge.description(context.l10n)),
          onTap: onPressed,
        ),
      ),
    );
  }

  void _showDeclineReasons(BuildContext context) {
    showAdaptiveActionSheet<void>(
      context: context,
      actions: ChallengeDeclineReason.values
          .map(
            (reason) => BottomSheetAction(
              makeLabel: (context) => Text(reason.label(context.l10n)),
              onPressed: (_) {
                onDecline?.call(reason);
              },
            ),
          )
          .toList(),
    );
  }
}

class CorrespondenceChallengeListItem extends StatelessWidget {
  const CorrespondenceChallengeListItem({
    super.key,
    required this.challenge,
    required this.user,
    this.onPressed,
    this.onCancel,
  });

  final CorrespondenceChallenge challenge;
  final LightUser user;
  final VoidCallback? onPressed;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return ChallengeListItem(
      challenge: Challenge(
        id: ChallengeId(challenge.id.value),
        status: ChallengeStatus.created,
        variant: challenge.variant,
        speed: Speed.correspondence,
        timeControl: ChallengeTimeControlType.correspondence,
        rated: challenge.rated,
        sideChoice: challenge.side == null
            ? SideChoice.random
            : challenge.side == Side.white
                ? SideChoice.white
                : SideChoice.black,
        days: challenge.days,
      ),
      user: user,
      onPressed: onPressed,
      onCancel: onCancel,
    );
  }
}
