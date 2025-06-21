use dep::aztec::macros::aztec;

#[aztec]
pub contract CTF {
    use aztec::{
        macros::{functions::{private, public, utility}, storage::{storage, storage_no_init}},
        messages::logs::note::encode_and_encrypt_note};

    use dep::aztec:: macros::{
        functions::{initializer, internal }, 
    };
    use dep::aztec::keys::getters::get_public_keys;
    use dep::aztec::prelude::{AztecAddress, Map, PublicImmutable, PublicMutable, PrivateMutable};
    use dep::aztec::protocol_types::traits::{Hash, ToField};
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
    }

    impl FlagNote {
        pub fn new(owner: AztecAddress) -> Self {
            FlagNote { owner }
        }
    }

    #[initializer]
    #[private]
    fn constructor() {
        let new_flag: FlagNote = FlagNote::new(context.msg_sender());
        storage.current_holder.replace(new_flag).emit(encode_and_encrypt_note(
            &mut context,
            context.msg_sender(),
            context.msg_sender(),
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

    #[private]
    fn has_flag() -> bool {
        let caller = context.msg_sender();
        let note = storage.current_holder.get_note();
        note.note.owner == caller
    }

}
