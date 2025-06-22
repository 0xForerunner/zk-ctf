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
    use dep::aztec::prelude::{AztecAddress, Map, SharedMutable, PublicImmutable, PublicMutable, PrivateMutable};
    use dep::aztec::protocol_types::traits::{Hash, ToField};
    use aztec::{
        macros::notes::note,
        protocol_types::{traits::{Deserialize, Serialize}},
    };
    use aztec::protocol_types::traits::Packable;
use dep::value_note::value_note::ValueNote;

    use aztec::{
        macros::{events::event}
    };

    #[storage]
    struct Storage<Context> {
        admin: PublicImmutable<AztecAddress, Context>,
        start: PublicImmutable<u32, Context>,
        end: PublicImmutable<u32, Context>,
        join_fee: PublicImmutable<Field, Context>,
        challenge_fee: PublicImmutable<Field, Context>,
        slash_fee: PublicImmutable<Field, Context>,
        deposit_size: PublicImmutable<Field, Context>,
        deposits: Map<AztecAddress, PublicMutable<Field, Context>, Context>,
        challenger: Map<AztecAddress, PublicMutable<AztecAddress, Context>, Context>,
        challenge_block: Map<AztecAddress, SharedMutable<u32, 1, Context>, Context>,
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
        tally: u32,
    }

    impl TallyNote {
        pub fn new(owner: AztecAddress) -> Self {
            TallyNote { owner, tally: 0 }
        }
    }

    // Define an event structure
    #[event]
    struct ChallengeEvent {
        challenger: AztecAddress,
        defender: AztecAddress,
        block: Field
    }

    #[private]
    fn join(game_id: AztecAddress) {

        let amount: Field = storage.deposit_size.read();            // immutable
        // let deposit_note  = ValueNote {                             // struct fields

        // Emit encrypted log so the contract (recipient) can decrypt & spend later.
        // The *sender* is the player; the *recipient* is the contract itself.
        encode_and_encrypt_note(
            &mut context,
            context.this_address(),
            context.msg_sender(),
        )
        .emit_note(deposit_note);  

    
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
    fn tally() -> u32 {
        let note = storage.tally_note.at(context.msg_sender()).get_note();
        note.note.tally
    }

    #[public]
    fn challenge(address: AztecAddress) {
        let challenger = storage.challenger.at(address).read();
    
        // Abort if someone has already written to this key
        assert(challenger != AztecAddress::zero(), "Challenge already exists for this address");

        let challenger = context.msg_sender();

        // emit_event_in_public_log(
        //     ChallengeEvent { challenger: challenger, defender: address, block: context.block_number() },
        //     &mut context,
        // );

    }

    #[public]
    fn slash(address: AztecAddress) {
        let challenger = storage.challenger.at(address).read();
    
        // Abort if someone has already written to this key
        assert(challenger == context.msg_sender(), "You are not the challenger for this address");

    let reward = ValueNote::new(
        context.msg_sender(),
        storage.slash_fee.read(),
    );

    encode_and_encrypt_note(&mut context, caller, context.this_address())
        .emit_note(reward);

    }

    #[private]
    fn respond(challenger: AztecAddress) {
        let slot = storage.capture_note.at(context.msg_sender());
        let capture_note = slot.get_note().note;
        let challenge_block = storage.challenge_block.at(context.msg_sender()).get_current_value();


        let tally_note = storage.tally_note.at(context.msg_sender()).get_note().note;
        let mut new_tally = tally_note.tally;


        if capture_note.capture_block != 0 {
            new_tally = tally_note.tally + challenge_block - capture_note.capture_block;
        }

        // Relinquish the flag
        let new_capture_note = CaptureNote::new(context.msg_sender());
        slot.replace(new_capture_note).emit(encode_and_encrypt_note(
            &mut context,
            challenger,
            context.msg_sender(),
        ));

        // emit the old note to the challenger
        let challenger_slot = storage.capture_note.at(challenger);
        let challenger_capture_note = CaptureNote {
            owner: challenger,
            capture_block: challenge_block,
        };
        slot.replace(challenger_capture_note).emit(encode_and_encrypt_note(
            &mut context,
            challenger,
            context.msg_sender(),
        ));

        // Publically ack the challenge
        CTF::at(context.this_address())
            ._respond(context.msg_sender())
            .enqueue(&mut context);
    }

    #[public]
    #[internal]
    fn _respond(sender: AztecAddress) {
        storage.challenger.at(sender).write(AztecAddress::zero());
        storage.challenge_block.at(sender).schedule_value_change(0);
    }

}
