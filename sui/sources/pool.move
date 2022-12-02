module memo::memo_pool {
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::event;

    /// For when Coin balance is too low.
    const ENotEnough: u64 = 0;

    /// Capability that grants an owner the right to withdrawal.
    struct PoolOwnerCap has key { id: UID }

    struct MemoPool has key {
        id: UID,
        balance: Balance<SUI>
    }

    // ====== Events ======

    /// For when someone deposit sui.
    struct Deposit has copy, drop {
        sender: address, 
        amount: u64
    }

    // ====== Functions ======

    fun init(ctx: &mut TxContext) {
        transfer::transfer(PoolOwnerCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));

        transfer::share_object(MemoPool {
            id: object::new(ctx),
            balance: balance::zero()
        })
    }

    // ====== MemoPool Entrypoints ======

    /// Deposit sui into memo pool and emit deposit event.
    /// transfer memo into sender on the memo chain
    public entry fun deposit(
        pool: &mut MemoPool, 
        payment: &mut Coin<SUI>, 
        amount: u64, 
        ctx: &mut TxContext
    ) {
        assert!(coin::value(payment) >= amount, ENotEnough);

        let coin_balance = coin::balance_mut(payment);
        let paid = balance::split(coin_balance, amount);

        balance::join(&mut pool.balance, paid);

        // Emit the event.
        event::emit(Deposit {  
            sender: tx_context::sender(ctx), 
            amount: amount});
    }

    /// Deposit sui into memo pool and emit deposit event.
    /// transfer memo into memo address on the memo chain
    public entry fun deposit_with_address(
        pool: &mut MemoPool, 
        payment: &mut Coin<SUI>, 
        amount: u64, 
        memo_address: address, 
        _ctx: &mut TxContext
    ) {
        assert!(coin::value(payment) >= amount, ENotEnough);

        let coin_balance = coin::balance_mut(payment);
        let paid = balance::split(coin_balance, amount);

        balance::join(&mut pool.balance, paid);

        // Emit the event.
        event::emit(Deposit {  
            sender: memo_address, 
            amount: amount});
    }

    /// Pool owner has ability to collect profits from "MemoPool"
    /// Withdraw sui from "MemoPool" and transfer it to receiver.
    /// Requires authorization with "PoolOwnerCap".
    public entry fun collect_profits(
        _: &PoolOwnerCap, 
        pool: &mut MemoPool, 
        amount: u64, 
        receiver: address, 
        ctx: &mut TxContext
    ) {
        let profits = coin::take(&mut pool.balance, amount, ctx);

        transfer::transfer(profits, receiver)
    }
}
