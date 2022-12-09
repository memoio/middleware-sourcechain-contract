module memo::memo_pool {
    use std::signer;
    use std::error;
    use aptos_std::event::{emit_event, EventHandle};
    use aptos_std::account::new_event_handle;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;

    const EAdrressMismatch: u64 = 0;
    const EModuleAlreadInited: u64 = 1;

    struct MemoPool has key {
        balance: coin::Coin<AptosCoin>, 
        deposit_events: EventHandle<DepositEvent>
    }

    // ====== Events ======

    /// For when someone deposit aptos.
    struct DepositEvent has store, drop {
        receiver: address,
        amount: u64
    }

    // ====== Functions ======

    fun init_module(admin: &signer) {
        assert!(
            @memo == signer::address_of(admin) ,
            error::invalid_argument(EAdrressMismatch),
        );
        assert!(
            !exists<MemoPool>(signer::address_of(admin)),
            error::already_exists(EModuleAlreadInited),
        );

        move_to(admin, MemoPool {
            balance: coin::zero<AptosCoin>(), 
            deposit_events: new_event_handle<DepositEvent>(admin)
        })
    }

    // ====== MemoPool Entrypoints ======

    /// Deposit sui into memo pool and emit deposit event.
    /// transfer memo into sender on the memo chain
    public entry fun deposit(
        account: &signer, 
        amount: u64, 
    ) acquires MemoPool {
        if (amount > 0) {
            let pool = borrow_global_mut<MemoPool>(@memo);

            let paid = coin::withdraw<AptosCoin>(account, amount);
            coin::merge(&mut pool.balance, paid);

            emit_event(
                &mut pool.deposit_events,
                DepositEvent {
                    receiver: signer::address_of(account),
                    amount: amount
                }
            )
        } 
    }

    /// Deposit sui into memo pool and emit deposit event.
    /// transfer memo into memo address on the memo chain
    public entry fun deposit_with_address(
        account: &signer, 
        amount: u64, 
        memo_address: address, 
    ) acquires MemoPool {
        if (amount > 0) {
            let pool = borrow_global_mut<MemoPool>(@memo);

            let paid = coin::withdraw<AptosCoin>(account, amount);
            coin::merge(&mut pool.balance, paid);

            emit_event(
                &mut pool.deposit_events,
                DepositEvent {
                    receiver: memo_address,
                    amount: amount
                }
            )
        }
    }

    /// Pool owner has ability to collect profits from "MemoPool"
    /// Withdraw sui from "MemoPool" and transfer it to receiver.
    /// Requires authorization with "PoolOwnerCap".
    public entry fun collect_profits(
        admin: &signer,  
        amount: u64, 
        receiver: address, 
    ) acquires MemoPool {
        assert!(
            @memo == signer::address_of(admin), 
            error::invalid_argument(EAdrressMismatch),
        );

        let pool = borrow_global_mut<MemoPool>(signer::address_of(admin));

        let coin = coin::extract(&mut pool.balance, amount);
        coin::deposit(receiver, coin);
    }
}
