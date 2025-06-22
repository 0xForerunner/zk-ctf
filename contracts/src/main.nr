use dep::aztec::macros::aztec;

#[aztec]
pub contract CTF {
    use dep::aztec::oracle::random::random;
    use aztec::{
        macros::{functions::{private, public, utility}, storage::{storage, storage_no_init}},
        messages::logs::note::encode_and_encrypt_note};

    use dep::aztec:: macros::{
        functions::{initializer, internal }, 
    };
    use dep::aztec::keys::getters::get_public_keys;
    use dep::aztec::prelude::{AztecAddress, Map, PublicImmutable, PublicMutable, PrivateMutable};
    use dep::aztec::prelude::FunctionSelector;
    use aztec::context::{PublicContext, PrivateContext, UtilityContext};
    use dep::aztec::protocol_types::traits::{Hash, ToField, FromField};
    use dep::aztec::{
        macros::notes::note,
        protocol_types::{traits::{Deserialize, Serialize}},
    };

    #[storage]
    struct Storage<Context> {
        current_holder: PrivateMutable<FlagNote, Context>,
        temp_note: PrivateMutable<FlagNote, Context>,
    }

    #[note]
    #[derive(Eq, Serialize, Deserialize)]
    pub struct FlagNote {
        owner: AztecAddress,
        randomness: Field
    }

    impl FlagNote {
        pub fn new(owner: AztecAddress) -> Self {
            // Safety: We use the randomness to preserve the privacy of the note recipient by preventing brute-forcing,
            // so a malicious sender could use non-random values to make the note less private. But they already know
            // the full note pre-image anyway, and so the recipient already trusts them to not disclose this
            // information. We can therefore assume that the sender will cooperate in the random value generation.
            let randomness: Field = unsafe { random() };
            FlagNote { owner, randomness }
        }
    }

    #[initializer]
    #[private]
    fn constructor() {
        let owner = context.msg_sender();
        let new_flag: FlagNote = FlagNote::new(owner);
        let contract_owner = context.this_address();
        // storage.current_holder.initialize(new_flag).emit(encode_and_encrypt_note(
        //         &mut context,
        //         // context.msg_sender(),
        //         // context.msg_sender(),
        //         owner,
        //         owner
        // ));

        // Emit note for contract
        storage.current_holder.initialize(new_flag).emit(encode_and_encrypt_note(
            &mut context,
            contract_owner,
            context.msg_sender(),
        ));
    }


    // #[private]
    // fn claim(potential_holder: AztecAddress) {
    //     // This function is called by a user
    //     let user_address = context.msg_sender();
        
    //     // You can call another private function from here
    //     let note = call_self();

    //     if(note.owner == potential_holder) {
    //         let new_flag: FlagNote = FlagNote::new(context.msg_sender());
    //         storage.current_holder.replace(new_flag).emit(encode_and_encrypt_note(
    //             &mut context,
    //             context.msg_sender(),
    //             context.msg_sender(),
    //         ));
    //     }
    // }

    // #[private]
    // fn call_self() {
    //     let contract_address = context.this_address();
    //     let res = context.call_private_function(contract_address,"read_flag_note_as_contract", []       );
    // }

    // #[private]
    // fn read_flag_note_as_contract() -> pub FlagNote {
    //     let flag_note = storage.current_holder.get_note().note;
    //     flag_note
    // }

    #[private]
    fn claim(potential_holder: AztecAddress) {
        let user_address = context.msg_sender();
        
        // Call the function and store result
        call_self(context.inputs, user_address);
        
        // Retrieve the stored result
        let note = storage.temp_note.get_note().note;
        
        if(note.owner == potential_holder) {
            let new_flag: FlagNote = FlagNote::new(context.msg_sender());
            storage.current_holder.replace(new_flag).emit(encode_and_encrypt_note(
                &mut context,
                context.msg_sender(),
                context.msg_sender(),
            ));
        }
    }

    fn call_self(user_address: AztecAddress) {
        let contract_address = context.this_address();
        let selector = FunctionSelector::from_signature("read_flag_note_as_contract(AztecAddress)");
        // context.call_private_function(contract_address, selector, [user_address.to_field()]);
        read_flag_note_as_contract(context.inputs, user_address);
    }

    #[private]
    #[internal]
    fn read_flag_note_as_contract(user_address: AztecAddress) {
        let flag_note = storage.current_holder.get_note().note;
        // Store the result instead of returning it
        storage.temp_note.initialize(flag_note).emit(encode_and_encrypt_note(
            &mut context,
            user_address,
            context.msg_sender(),
        ))
    }

    // #[private]
    // fn claim(potential_holder: AztecAddress) {
    //     let contract_owner = context.this_address();

    //     let note = storage.current_holder.get_note(contract_owner);

    //     // let current_holder = storage.current_holder.get_note(contract_owner).note;
    //     // if(current_holder.owner == potential_holder) {
    //     //     let new_flag: FlagNote = FlagNote::new(context.msg_sender());
    //     //     storage.current_holder.replace(new_flag).emit(encode_and_encrypt_note(
    //     //         &mut context,
    //     //         context.msg_sender(),
    //     //         context.msg_sender(),
    //     //     ));
    //     // }
    // }

}