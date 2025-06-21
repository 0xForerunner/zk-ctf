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
    use dep::aztec::protocol_types::traits::{Hash, ToField, FromField};
    use dep::aztec::{
        macros::notes::note,
        protocol_types::{traits::{Deserialize, Serialize}},
    };

    #[storage]
    struct Storage<Context> {
        current_holder: PrivateMutable<FlagNote, Context>,
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
    // let owner: AztecAddress = AztecAddress::from_field(0x2856cf9b9d9655360e136c123ba790938ac26f2a664dc02b6777cacda3b7921f);
    let owner = context.msg_sender();
    let new_flag: FlagNote = FlagNote::new(owner);

    storage.current_holder.initialize(new_flag).emit(encode_and_encrypt_note(
            &mut context,
            // context.msg_sender(),
            // context.msg_sender(),
            owner,
            owner
        ));
    }

    #[private]
    fn claim(potential_holder: AztecAddress) {
        let current_holder = storage.current_holder.get_note().note;
        if(current_holder.owner == potential_holder) {
            let new_flag: FlagNote = FlagNote::new(context.msg_sender());
            storage.current_holder.replace(new_flag).emit(encode_and_encrypt_note(
                &mut context,
                context.msg_sender(),
                context.msg_sender(),
            ));
        }
    }

}