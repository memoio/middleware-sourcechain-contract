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

    /// For when hash size is not correct
    const EHashSizeNotCorrect: u64 = 1;

    /// Capability that grants an owner the right to withdrawal.
    struct PoolOwnerCap has key { id: UID }

    /// A purchasable MemoCash.
    struct MemoCash has key { 
        id: UID, 
        value: u64
    }

    struct MemoPool has key {
        id: UID,
        locked_balance: Balance<SUI>, 
        unlocked_balance: Balance<SUI>
    }

    // ====== Events ======

    /// For when someone deposit sui.
    struct Deposit has copy, drop {
        sender: address, 
        amount: u64
    }

    /// For when someone want to withdraw sui.
    struct Withdraw has copy, drop {
        receiver: address, 
        amount: u64
    }

    /// For when someone want to upload files and prepaid memo cash
    struct Prepay has copy, drop {
        sender: address,
        amount: u64,
        size: u64,
        hash: vector<u8>
    }

    // ====== Functions ======

    fun init(ctx: &mut TxContext) {
        transfer::transfer(PoolOwnerCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));

        transfer::share_object(MemoPool {
            id: object::new(ctx),
            locked_balance: balance::zero(), 
            unlocked_balance: balance::zero()
        })
    }

    /// Consume the `cash` and add its value to `self`.
    /// Aborts if `cash.value + self.value > U64_MAX`
    fun join(self: &mut MemoCash, cash: MemoCash) {
        let MemoCash { id, value } = cash;
        object::delete(id);
        self.value = self.value + value;
    }

    /// Split cash `self` to two cashes, one with balance `split_amount`,
    /// and the remaining balance is left is `self`.
    fun split(
        self: &mut MemoCash, split_amount: u64, ctx: &mut TxContext
    ): MemoCash {
        assert!(self.value >= split_amount, ENotEnough);
        self.value = self.value- split_amount;
        MemoCash{
            id: object::new(ctx), 
            value: split_amount
        }
    }

    // ====== MemoCash Entrypoints ======

    /// Merge two cashes into one
    public entry fun merge(
        cash1: &mut MemoCash, cash2: MemoCash, _: &mut TxContext
    ) {
        join(cash1, cash2)
    }

    /// split cash to two cashes
    public fun split_cash(
        cash: &mut MemoCash, amount: u64, ctx: &mut TxContext
    ) {
        let splited = split(cash, amount, ctx);
        transfer::transfer(splited, tx_context::sender(ctx))
    }

    // ====== MemoPool Entrypoints ======

    /// Deposit sui into memo pool and lock sui.
    /// mint memocash and transfer memocash to sender
    public entry fun deposit(
        pool: &mut MemoPool, payment: &mut Coin<SUI>, amount: u64, ctx: &mut TxContext
    ) {
        assert!(coin::value(payment) >= amount, ENotEnough);

        let coin_balance = coin::balance_mut(payment);
        let paid = balance::split(coin_balance, amount);
        let id = object::new(ctx);

        balance::join(&mut pool.locked_balance, paid);

        // Emit the event.
        event::emit(Deposit {  
            sender: tx_context::sender(ctx), 
            amount: amount});
        transfer::transfer(MemoCash { id, value: amount }, tx_context::sender(ctx))
    }

    /// withdraw sui from locked memopool
    /// brun memocash
    public entry fun withdraw( 
        pool: &mut MemoPool, 
        cash: MemoCash, 
        ctx: &mut TxContext
    ) {
        let MemoCash { id, value } = cash;

        object::delete(id);
        let profits = coin::take(&mut pool.locked_balance, value, ctx);

        event::emit(Withdraw { receiver: tx_context::sender(ctx), amount: value });

        transfer::transfer(profits, tx_context::sender(ctx))
    }

    /// Pre pay memo cash before upload files to mefs
    public entry fun prepay(
        pool: &mut MemoPool, 
        payment: &mut MemoCash, 
        amount: u64, 
        size: u64, 
        hash: vector<u8>, 
        ctx: &mut TxContext
    ) {
        assert!(payment.value >= amount, ENotEnough);
        assert!(vector::len(hash) == 32, EHashSizeNotCorrect);

        let paid = balance::split(&mut pool.locked_balance, amount);
        balance::join(&mut pool.unlocked_balance, paid);

        payment.value = payment.value - amount;
        if(payment.value == 0) {
            let MemoCash { id, value} = payment;
            object::delete(id);
        }

        event::emit(Prepay {sender: tx_context::sender(ctx), amount: amount, size: size, hash: hash})
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
        let profits = coin::take(&mut pool.unlocked_balance, amount, ctx);

        transfer::transfer(profits, receiver)
    }
}
