module wheatchain::events {
    use sui::event;
    use sui::tx_context::TxContext;

    struct StakeEvent has copy, drop {
        staker: address,
        amount: u64,
        epoch: u64,
    }

    struct RewardClaimedEvent has copy, drop {
        claimant: address,
        amount: u64,
    }

    struct UnstakeEvent has copy, drop {
        staker: address,
        amount: u64,
    }

    public fun emit_stake_event(staker: address, amount: u64, epoch: u64) {
        event::emit(StakeEvent { staker, amount, epoch });
    }

    public fun emit_reward_claimed_event(claimant: address, amount: u64) {
        event::emit(RewardClaimedEvent { claimant, amount });
    }

    public fun emit_unstake_event(staker: address, amount: u64) {
        event::emit(UnstakeEvent { staker, amount });
    }
}
