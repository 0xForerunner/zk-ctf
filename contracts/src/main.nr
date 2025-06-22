use dep::aztec::macros::aztec;

#[aztec]
pub contract CTF {
    use aztec::{
        macros::{functions::{private, public, view}, storage::{storage}},
        messages::logs::note::encode_and_encrypt_note};

    use dep::aztec:: macros::{
        functions::{internal}, 
    };
    use dep::aztec::prelude::{AztecAddress, Map, SharedMutable, PublicImmutable, PublicMutable, PrivateMutable};
    use aztec::{
        macros::notes::note,
        protocol_types::{traits::{Deserialize, Serialize}},
    };
    use aztec::protocol_types::traits::Packable;

    use aztec::{
        macros::{events::event}
    };

    use aztec::oracle::random::{random};   // returns a Field

    #[storage]
    struct Storage<Context> {
        start: PublicImmutable<u32, Context>,
        end: PublicImmutable<u32, Context>,
        join_fee: PublicImmutable<Field, Context>,
        challenge_fee: PublicImmutable<Field, Context>,
        slash_fee: PublicImmutable<Field, Context>,
        deposit_size: PublicImmutable<Field, Context>,
        is_init: PublicMutable<bool, Context>,
        num_players: PublicMutable<u32, Context>,
        deposits: Map<AztecAddress, PublicMutable<Field, Context>, Context>,
        challenger: Map<AztecAddress, PublicMutable<AztecAddress, Context>, Context>,
        challenge_block: Map<AztecAddress, SharedMutable<u32, 1, Context>, Context>,
        
        final_score: Map<AztecAddress, SharedMutable<u32, 1, Context>, Context>,
        game_over: SharedMutable<bool, 1, Context>,
        winner: SharedMutable<AztecAddress, 1, Context>,
        winner_score: SharedMutable<u32, 1, Context>,
        
        first_capture: SharedMutable<bool, 1, Context>,
        
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
        randomness: Field
    }

    impl CaptureNote {
        pub fn new(owner: AztecAddress, capture_block: u32) -> Self {
            // Safety: We use the randomness to preserve the privacy of the note recipient by preventing brute-forcing,
            // so a malicious sender could use non-random values to make the note less private. But they already know
            // the full note pre-image anyway, and so the recipient already trusts them to not disclose this
            // information. We can therefore assume that the sender will cooperate in the random value generation.
            let randomness: Field = unsafe { random() };
            CaptureNote { owner, capture_block, randomness }
        }
    }

    #[note]
    #[derive(Eq, Serialize, Deserialize)]
    pub struct TallyNote {
        owner: AztecAddress,
        tally: u32,
        randomness: Field

    }

    impl TallyNote {
        pub fn new(owner: AztecAddress, tally: u32) -> Self {
            // Safety: We use the randomness to preserve the privacy of the note recipient by preventing brute-forcing,
            // so a malicious sender could use non-random values to make the note less private. But they already know
            // the full note pre-image anyway, and so the recipient already trusts them to not disclose this
            // information. We can therefore assume that the sender will cooperate in the random value generation.
            let randomness: Field = unsafe { random() };

            TallyNote { owner, tally , randomness}
        }
    }

    // Define an event structure
    #[event]
    #[derive(Eq, Serialize, Deserialize)]
    struct ChallengeEvent {
        challenger: AztecAddress,
        defender: AztecAddress,
        block: Field
    }

    // #[initializer]
    #[public]
    fn initialize(
        start: u32, 
        end: u32,
        join_fee: Field,
        challenge_fee: Field,
        slash_fee: Field,
        deposit_size: Field,
    ) {
        storage.start.initialize(start);
        storage.end.initialize(end);
        storage.join_fee.initialize(join_fee);
        storage.challenge_fee.initialize(challenge_fee);
        storage.slash_fee.initialize(slash_fee);
        storage.deposit_size.initialize(deposit_size);
        storage.num_players.write(0);
        
    }

    #[private]
    fn join(want_flag: bool, block_number: u32) {
        if(want_flag) {
            let capture_note = CaptureNote::new(context.msg_sender(), block_number);
            let tally_note = TallyNote::new(context.msg_sender(), 0);
            storage.capture_note.at(context.msg_sender()).initialize_or_replace(capture_note).emit(encode_and_encrypt_note(
                &mut context,
                context.msg_sender(),
                context.msg_sender(),
            ));
            storage.tally_note.at(context.msg_sender()).initialize_or_replace(tally_note).emit(encode_and_encrypt_note(
                &mut context,
                context.msg_sender(),
                context.msg_sender(),
            ));
        } else {
            let capture_note = CaptureNote::new(context.msg_sender(), 0);
            let tally_note = TallyNote::new(context.msg_sender(), 0);
            storage.capture_note.at(context.msg_sender()).initialize_or_replace(capture_note).emit(encode_and_encrypt_note(
                &mut context,
                context.msg_sender(),
                context.msg_sender(),
            ));
            storage.tally_note.at(context.msg_sender()).initialize_or_replace(tally_note).emit(encode_and_encrypt_note(
                &mut context,
                context.msg_sender(),
                context.msg_sender(),
            ));
        }

    }

    #[private]
    fn has_flag() -> bool {
        let note = storage.capture_note.at(context.msg_sender()).get_note();
        note.note.capture_block != 0
    }

    #[public]
    fn end_game() {
        let current_block = context.block_number() as u32;
        // You can now use current_block for your logic
        if current_block > storage.end.read() {
            storage.game_over.schedule_value_change(true);
        }
    }

    #[public]
    fn winner() -> AztecAddress {
        let mut winner = AztecAddress::zero();
        let current_block = context.block_number() as u32;
        if current_block > storage.end.read() {
            winner = storage.winner.get_current_value();
        }

        winner 
    }

    #[private]
    fn submit_score() {
        let score: TallyNote = storage.tally_note.at(context.msg_sender()).get_note().note;
        CTF::at(context.this_address())
            ._submit_score(context.msg_sender(), score.tally)
            .enqueue(&mut context);
    }

    #[public]
    #[internal]
    fn _submit_score(sender: AztecAddress, score: u32) {
        let (gameOver, _) = storage.game_over.get_scheduled_value();

        if(gameOver) {
            storage.final_score.at(sender).schedule_value_change(score);
            let (winner_score, _) = storage.winner_score.get_scheduled_value();
            if(winner_score < score) {
                storage.winner_score.schedule_value_change(score);
                storage.winner.schedule_value_change(sender);
            }
        }
    }

    #[private]
    fn tally() -> u32 {
        let note = storage.tally_note.at(context.msg_sender()).get_note();
        note.note.tally
    }

    #[public]
    fn challenge(address: AztecAddress) {
        // Ensure the game is initialized
        if !storage.is_init.read() {}
        let challenger = storage.challenger.at(address).read();
    
        // Abort if someone has already written to this key
        assert(challenger != AztecAddress::zero(), "Challenge already exists for this address");

        let challenger = context.msg_sender();

        context.emit_public_log(
            ChallengeEvent { challenger: challenger, defender: address, block: context.block_number() }        );

        storage.challenger.at(address).write(context.msg_sender());
        storage.challenge_block.at(address).schedule_value_change(context.block_number() as u32);
    }

    #[public]
    fn slash(address: AztecAddress) {
        let challenger = storage.challenger.at(address).read();
    
        // Abort if someone has already written to this key
        assert(challenger == context.msg_sender(), "You are not the challenger for this address");
    }

    #[private]
    fn respond(challenger: AztecAddress) {
        let responder_slot = storage.capture_note.at(context.msg_sender());
        let capture_note = responder_slot.get_note().note;
        let challenge_block = storage.challenge_block.at(context.msg_sender()).get_current_value();

        let tally_slot = storage.tally_note.at(context.msg_sender());
        let tally_note = tally_slot.get_note().note;
        let mut new_tally_note = TallyNote::new(context.msg_sender(), tally_note.tally);
        let mut new_capture_note = capture_note;
        let randomness: Field = unsafe { random() };
        let mut challenger_capture_note = CaptureNote {
            owner: challenger,
            capture_block: 0,
            randomness
        };

        if capture_note.capture_block != 0 {
            new_tally_note.tally = new_tally_note.tally + challenge_block - capture_note.capture_block;
            new_capture_note = CaptureNote::new(context.msg_sender(), 0);
            challenger_capture_note = CaptureNote {
                owner: challenger,
                capture_block: challenge_block,
                randomness
            };
        }

        // Emit the tally note
        tally_slot.initialize_or_replace(new_tally_note).emit(encode_and_encrypt_note(
            &mut context,
            context.msg_sender(),
            context.msg_sender(),
        ));

        // Relinquish the flag
        responder_slot.initialize_or_replace(new_capture_note).emit(encode_and_encrypt_note(
            &mut context,
            context.msg_sender(),
            context.msg_sender(),
        ));

        // emit the note to the challenger
        let challenger_slot = storage.capture_note.at(challenger);
        challenger_slot.initialize_or_replace(challenger_capture_note).emit(encode_and_encrypt_note(
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

    #[public]
    fn nothing() {
    }
}
