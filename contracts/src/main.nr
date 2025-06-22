use dep::aztec::macros::aztec;

#[aztec]
pub contract CTF {
    use aztec::{
        macros::{functions::{private, public, utility, view}, storage::{storage, storage_no_init}},
        messages::logs::note::encode_and_encrypt_note};

    use dep::aztec:: macros::{
        functions::{initializer, internal }, 
    };
    use dep::aztec::keys::getters::get_public_keys;
    use dep::aztec::prelude::{AztecAddress, Map, PublicImmutable, PublicMutable, PrivateMutable};
    use dep::aztec::protocol_types::traits::{Hash, ToField};
    use aztec::{
        macros::notes::note,
        protocol_types::{traits::{Deserialize, Serialize}},
    };
    use aztec::protocol_types::traits::Packable;

    #[storage]
    struct Storage<Context> {
        admin: PublicImmutable<AztecAddress, Context>,
        start: PublicImmutable<u32, Context>,
        end: PublicImmutable<u32, Context>,
        join_fee: PublicImmutable<Field, Context>,
        challenge_fee: PublicImmutable<Field, Context>,
        slash_fee: PublicImmutable<Field, Context>,
        deposit_size: PublicImmutable<Field, Context>,
        challenger: Map<AztecAddress, PublicMutable<AztecAddress, Context>, Context>,
        challenge_block: Map<AztecAddress, PublicMutable<u32, Context>, Context>,
        capture_note: Map<AztecAddress, PrivateMutable<CaptureNote, Context>, Context>,
        tally_note: Map<AztecAddress, PrivateMutable<TallyNote, Context>, Context>,
    }

    #[derive(Eq, Serialize, Deserialize, Packable)]
    struct Challenge {
        challenger: AztecAddress,
        block: u32,
    }

    #[note]
    #[derive(Eq, Serialize, Deserialize)]
    pub struct CaptureNote {
        owner: AztecAddress,
        // 0 indicates the player does not have the flag
        capture_block: u32,
    }


    impl CaptureNote {
        pub fn new(owner: AztecAddress) -> Self {
            CaptureNote { owner, capture_block: 0 }
        }
    }

    #[note]
    #[derive(Eq, Serialize, Deserialize)]
    pub struct TallyNote {
        owner: AztecAddress,
        tally: Field,
    }

    impl TallyNote {
        pub fn new(owner: AztecAddress) -> Self {
            TallyNote { owner, tally: 0 }
        }
    }

    #[initializer]
    #[private]
    fn constructor() {
        // let new_flag: FlagNote = FlagNote::new(context.msg_sender());
        // storage.current_holder.replace(new_flag).emit(encode_and_encrypt_note(
            // &mut context,
            // context.msg_sender(),
            // context.msg_sender(),
        // ));
    }

    #[private]
    fn join(game_id: AztecAddress) {
        let capture_note  = CaptureNote::new(context.msg_sender());
        let tally_note  = TallyNote::new(context.msg_sender());
        storage.capture_note.at(context.msg_sender()).replace(capture_note).emit(encode_and_encrypt_note(
            &mut context,
            context.msg_sender(),
            context.msg_sender(),
         ));
        storage.tally_note.at(context.msg_sender()).replace(tally_note).emit(encode_and_encrypt_note(
            &mut context,
            context.msg_sender(),
            context.msg_sender(),
         ));
    }

    #[view]
    #[private]
    fn has_flag() -> bool {
        let note = storage.capture_note.at(context.msg_sender()).get_note();
        note.note.capture_block != 0
    }

    #[view]
    #[private]
    fn tally() -> Field {
        let note = storage.tally_note.at(context.msg_sender()).get_note();
        note.note.tally
    }

    #[public]
    fn challenge(address: AztecAddress) {
        let challenger = storage.challenger.at(address).read();
    
        // Abort if someone has already written to this key
        assert(challenger != AztecAddress::zero(), "Challenge already exists for this address");

        let challenger = context.msg_sender();
    }

    #[private]
    fn respond(challenger: AztecAddress) {
        let slot = storage.capture_note.at(context.msg_sender());
        let note = slot.get_note().note;
        slot.replace(note).emit(encode_and_encrypt_note(
            &mut context,
            challenger,
            context.msg_sender(),
        ));

        CTF::at(context.this_address())
            ._respond(context.msg_sender())
            .enqueue(&mut context);
    }

    #[public]
    #[internal]
    fn _respond(sender: AztecAddress) {
        storage.challenger.at(sender).write(AztecAddress::zero());
        storage.challenge_block.at(sender).write(0);
    }

}
