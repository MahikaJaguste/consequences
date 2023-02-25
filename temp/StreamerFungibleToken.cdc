import FungibleToken from "./FungibleToken.cdc"

pub contract interface StreamerFungibleToken {

    pub var totalSupply: UFix64

    pub let VaultStoragePath: StoragePath
    pub let ReceiverPublicPath: PublicPath
    pub let BalancePublicPath: PublicPath
    pub let ProviderPrivatePath: PrivatePath
    pub let AdminStoragePath: StoragePath
    pub let MinterStoragePath: StoragePath

    pub event TokensInitialized(initialSupply: UFix64)
    pub event TokensWithdrawn(amount: UFix64, from: Address?)
    pub event TokensDeposited(amount: UFix64, to: Address?)

    pub resource interface StreamerProvider {
        pub fun withdraw(amount: UFix64): @StreamerVault {
            post {
                result.staticBalance == amount:
                    "Withdrawal amount must be the same as the balance of the withdrawn Vault"
            }
        }
    }

    pub resource interface StreamerReceiver {
        pub fun deposit(from: @StreamerVault )
    }

    pub resource interface StreamerBalance {

        pub var staticBalance: UFix64
        pub var latestTimeElapsed: UFix64
        pub var netFlowRate: UFix64

        init(balance: UFix64) {
            post {
                self.getBalance() == balance:
                    "Balance must be initialized to the initial balance"

                self.staticBalance == balance:
                    "Static balance must be initialized to the initial balance"

                self.latestTimeElapsed == 0.0:
                    "Time elapsed since last checkpoint should be zero on initialisation"
            }
        }

        pub fun getBalance(): UFix64
        pub fun getRealTimeBalance(currentTimestamp: UFix64): UFix64
    }

    pub resource StreamerVault: StreamerProvider, StreamerReceiver, StreamerBalance {

        pub var staticBalance: UFix64
        pub var latestTimeElapsed: UFix64
        pub var netFlowRate: UFix64

        init(balance: UFix64)

        pub fun withdraw(amount: UFix64): @StreamerVault 
        {
            pre {
                self.getBalance() >= amount:
                    "Amount withdrawn must be less than or equal than the balance of the Vault"
            }
        //     post {
        //         self.staticBalance == before(self.staticBalance) - amount + self.getTimeElapsedCost():
        //             "New Vault balance must be the difference of the previous balance and the withdrawn Vault with changes based on net flow rate"
        //     }
        }


        pub fun deposit(from: @StreamerVault ) 
        // {
        //     pre {
        //         from.isInstance(self.getType()): 
        //             "Cannot deposit an incompatible token type"
        //     }
        //     post {
        //         self.staticBalance == before(self.staticBalance) + before(from.getBalance()):
        //             "New Vault balance must be the sum of the previous balance and the deposited Vault"
        //     }
        // }

        pub fun getBalance(): UFix64
        pub fun getRealTimeBalance(currentTimestamp: UFix64): UFix64
    }

    pub fun createEmptyStreamerVault(): @StreamerVault {
        post {
            result.staticBalance == 0.0: "The newly created Vault must have zero real-time balance"
            result.getBalance() == 0.0: "The newly created Vault must have zero real-time balance"
            result.staticBalance == 0.0: "The newly created Vault must have zero static balance"
            result.latestTimeElapsed == 0.0: "The newly created Vault must have zero time elapsed"
            result.netFlowRate == 0.0: "The newly created Vault must have zero net flow rate"
        }
    }
}