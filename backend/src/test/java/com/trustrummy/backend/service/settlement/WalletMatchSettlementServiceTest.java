package com.trustrummy.backend.service.settlement;

import com.trustrummy.backend.entity.WalletTransaction;
import com.trustrummy.backend.service.WalletService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WalletMatchSettlementServiceTest {

    @Mock
    private WalletService walletService;

    private WalletMatchSettlementService settlement;

    @BeforeEach
    void setUp() {
        settlement = new WalletMatchSettlementService(walletService);
    }

    @Test
    void collectStakes_freePlay_isNoOpSuccess() {
        CollectStakesResult result = settlement.collectStakes(new CollectStakesCommand(
                "ROOM1", BigDecimal.ZERO, List.of(new SeatedPlayer(1L, "alice"))));

        assertThat(result.success()).isTrue();
        verifyNoInteractions(walletService);
    }

    @Test
    void collectStakes_insufficientBalance_returnsSameErrorText() {
        when(walletService.hasSufficientBalance(1L, new BigDecimal("25.00"))).thenReturn(true);
        when(walletService.hasSufficientBalance(2L, new BigDecimal("25.00"))).thenReturn(false);

        CollectStakesResult result = settlement.collectStakes(new CollectStakesCommand(
                "ROOM1",
                new BigDecimal("25.00"),
                List.of(new SeatedPlayer(1L, "alice"), new SeatedPlayer(2L, "bob"))));

        assertThat(result.success()).isFalse();
        assertThat(result.errorMessage())
                .isEqualTo("Cannot start: bob does not have enough wallet balance for the 25.00 stake");
        verify(walletService, never()).debitStake(any(), any(), any());
    }

    @Test
    void collectStakes_midDebitFailure_refundsAlreadyDebited() {
        when(walletService.hasSufficientBalance(any(), any())).thenReturn(true);
        when(walletService.debitStake(eq(1L), eq(new BigDecimal("10.00")), eq("ROOM1")))
                .thenReturn(new WalletTransaction());
        when(walletService.debitStake(eq(2L), eq(new BigDecimal("10.00")), eq("ROOM1")))
                .thenThrow(new IllegalStateException("insufficient"));

        CollectStakesResult result = settlement.collectStakes(new CollectStakesCommand(
                "ROOM1",
                new BigDecimal("10.00"),
                List.of(new SeatedPlayer(1L, "alice"), new SeatedPlayer(2L, "bob"))));

        assertThat(result.success()).isFalse();
        assertThat(result.errorMessage())
                .isEqualTo("Cannot start: a stake could not be collected, please try again");

        InOrder order = inOrder(walletService);
        order.verify(walletService).debitStake(1L, new BigDecimal("10.00"), "ROOM1");
        order.verify(walletService).debitStake(2L, new BigDecimal("10.00"), "ROOM1");
        order.verify(walletService).creditStakePayout(1L, new BigDecimal("10.00"), "ROOM1");
        verify(walletService, never()).creditStakePayout(eq(2L), any(), any());
    }

    @Test
    void settleStakes_nullWinner_doesNotPayout() {
        settlement.settleStakes(new SettleStakesCommand("ROOM1", new BigDecimal("25.00"), 2, null));

        verifyNoInteractions(walletService);
    }

    @Test
    void settleStakes_winnerTakesFullPot() {
        settlement.settleStakes(new SettleStakesCommand("ROOM1", new BigDecimal("25.00"), 2, 9L));

        verify(walletService).creditStakePayout(9L, new BigDecimal("50.00"), "ROOM1");
    }

    @Test
    void settleStakes_freePlay_isNoOp() {
        settlement.settleStakes(new SettleStakesCommand("ROOM1", BigDecimal.ZERO, 2, 9L));

        verifyNoInteractions(walletService);
    }
}
