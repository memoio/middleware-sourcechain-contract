module example::memo_pool {
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};

    // This is the only dependency you need for events.
    use sui::event;

    /// For when Coin balance is too low.
    const ENotEnough: u64 = 0;

    /// Capability that grants an owner the right to withdrawal.
    struct PoolOwnerCap has key { id: UID }

    /// A purchasable MemoCash.
    struct MemoCash has key { 
        id: UID, 
        value: u64
    }

    struct MemoPool has key {
        id: UID,
        balance: Balance<SUI>
    }

    // ====== Events ======

    /// For when someone has purchased a donut.
    struct Deposit has copy, drop {
        sender: address, 
        amount: u64
    }

    /// For when DonutShop owner has collected profits.
    struct Withdraw has copy, drop {
        receiver: address, 
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

    /// Deposit sui into memo pool.
    /// mint memocash and transfer memocash to sender
    public entry fun deposit(
        pool: &mut MemoPool, payment: &mut Coin<SUI>, amount: u64, ctx: &mut TxContext
    ) {
        assert!(coin::value(payment) >= amount, ENotEnough);

        let coin_balance = coin::balance_mut(payment);
        let paid = balance::split(coin_balance, amount);
        let id = object::new(ctx);

        balance::join(&mut pool.balance, paid);

        // Emit the event.
        event::emit(Deposit {  
            sender: tx_context::sender(ctx), 
            amount: amount});
        transfer::transfer(MemoCash { id, value: amount }, tx_context::sender(ctx))
    }

    // withdraw sui from mempool
    // brun memocash
    public entry fun withdraw( 
        pool: &mut MemoPool, 
        cash: MemoCash, 
        ctx: &mut TxContext
    ) {
        let MemoCash { id, value } = cash;

        object::delete(id);
        let profits = coin::take(&mut pool.balance, value, ctx);

        event::emit(Withdraw { receiver: tx_context::sender(ctx), amount: value });

        transfer::transfer(profits, tx_context::sender(ctx))
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
