package com.trustrummy.backend.service.settlement;

import com.trustrummy.backend.service.WalletService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

/**
 * Ledger-backed {@link MatchSettlementService} that preserves the historical
 * stake loop: {@link WalletService#debitStake} / {@link WalletService#creditStakePayout},
 * including mid-collect refunds via {@code creditStakePayout}.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class WalletMatchSettlementService implements MatchSettlementService {

    private final WalletService walletService;

    @Override
    public CollectStakesResult collectStakes(CollectStakesCommand command) {
        BigDecimal stake = command.stakeAmount() != null ? command.stakeAmount() : BigDecimal.ZERO;
        if (stake.compareTo(BigDecimal.ZERO) <= 0) {
            return CollectStakesResult.ok();
        }

        List<SeatedPlayer> seated = command.seatedPlayers();
        for (SeatedPlayer player : seated) {
            if (!walletService.hasSufficientBalance(player.userId(), stake)) {
                return CollectStakesResult.failed(
                        "Cannot start: " + player.username()
                                + " does not have enough wallet balance for the " + stake + " stake");
            }
        }

        List<SeatedPlayer> debited = new ArrayList<>();
        try {
            for (SeatedPlayer player : seated) {
                walletService.debitStake(player.userId(), stake, command.roomCode());
                debited.add(player);
            }
            return CollectStakesResult.ok();
        } catch (Exception ex) {
            log.error("Stake collection failed for room={} after debiting {}/{} players; refunding",
                    command.roomCode(), debited.size(), seated.size(), ex);
            for (SeatedPlayer player : debited) {
                try {
                    walletService.creditStakePayout(player.userId(), stake, command.roomCode());
                } catch (Exception refundEx) {
                    log.error("Stake refund failed for user={} room={} — manual reconciliation required",
                            player.userId(), command.roomCode(), refundEx);
                }
            }
            return CollectStakesResult.failed("Cannot start: a stake could not be collected, please try again");
        }
    }

    @Override
    public void settleStakes(SettleStakesCommand command) {
        BigDecimal stake = command.stakeAmount();
        if (stake == null || stake.compareTo(BigDecimal.ZERO) <= 0) {
            return;
        }
        if (command.winnerUserId() == null) {
            log.warn("Match in room={} ended with stakes collected but no winner to pay out; pot is not refunded",
                    command.roomCode());
            return;
        }
        BigDecimal pot = stake.multiply(BigDecimal.valueOf(command.seatCount()));
        try {
            walletService.creditStakePayout(command.winnerUserId(), pot, command.roomCode());
            log.info("Stake payout: room={} winner={} pot={}", command.roomCode(), command.winnerUserId(), pot);
        } catch (Exception ex) {
            log.error("Stake payout failed for room={} winner={} pot={} — manual reconciliation required",
                    command.roomCode(), command.winnerUserId(), pot, ex);
        }
    }
}
