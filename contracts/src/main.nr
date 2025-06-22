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
    use token::Token;
    use aztec::{
        macros::{events::event}
    };

    use aztec::oracle::random::{random};   // returns a Field

    #[storage]
    struct Storage<Context> {
        start: PublicImmutable<u32, Context>,
        end: PublicImmutable<u32, Context>,
        claim: PublicImmutable<u32, Context>,
        spend_limit: PublicImmutable<u128, Context>,
        challenge_fee: PublicImmutable<u128, Context>,
        deposit_size: PublicImmutable<u128, Context>,
        token: PublicImmutable<AztecAddress, Context>,

        pot: PublicMutable<u128, Context>,
        deposits: Map<AztecAddress, PublicMutable<u128, Context>, Context>,
        challenger: Map<AztecAddress, PublicMutable<AztecAddress, Context>, Context>,
        challenge_block: Map<AztecAddress, SharedMutable<u32, 1, Context>, Context>,
        
        final_score: Map<AztecAddress, SharedMutable<u32, 1, Context>, Context>,
        winner: SharedMutable<AztecAddress, 1, Context>,
        winner_score: SharedMutable<u32, 1, Context>,
        
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

    #[event]
    #[derive(Eq, Serialize, Deserialize)]
    struct TallyEvent {
        address: AztecAddress,
        tally: u32,
    }

    #[public]
    fn initialize(
        start: u32, 
        end: u32,
        claim: u32,
        spend_limit: u128,
        challenge_fee: u128,
        deposit_size: u128,
        token: AztecAddress,
    ) {
        storage.start.initialize(start);
        storage.end.initialize(end);
        storage.claim.initialize(claim);
        storage.spend_limit.initialize(spend_limit);
        storage.challenge_fee.initialize(challenge_fee);
        storage.deposit_size.initialize(deposit_size);
        storage.token.initialize(token);
    }

    #[private]
    fn join(want_flag: bool) {
        Token::at(storage.token.read())
            .transfer_to_public(
                context.msg_sender(),
                context.this_address(),
                storage.deposit_size.read(),
                0
            )
            .call(&mut context);  

        let mut capture_block = if want_flag {
            storage.start.read()
        } else {
            0
        };

        let capture_note = CaptureNote::new(context.msg_sender(), capture_block);
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

        CTF::at(context.this_address())
            ._join(context.msg_sender())
            .enqueue(&mut context);
    }

    #[public]
    #[internal]
    fn _join(sender: AztecAddress) {
        // assert(context.block_number() as u32 < storage.start.read(), "Game has already started");
        storage.deposits.at(sender).write(storage.deposit_size.read());
    }

    #[public]
    fn claim() {
        assert(context.block_number() as u32 > storage.claim.read(), "Claim period has not started yet");
        let mut refund = storage.deposits.at(context.msg_sender()).read();
        if context.msg_sender() == storage.winner.get_current_value() {
            refund += storage.pot.read();
        }
        Token::at(storage.token.read())
            .transfer_in_public(
                context.this_address(),
                context.msg_sender(),
                refund,
                0
            )
            .call(&mut context);
    }

    #[private]
    fn has_flag() -> bool {
        let note = storage.capture_note.at(context.msg_sender()).get_note();
        note.note.capture_block != 0
    }

    #[public]
    fn end_game() {
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

    #[public]
    fn winner_score() -> u32 {
        let mut winner_score = 0;
        let current_block = context.block_number() as u32;
        if current_block > storage.end.read() {
            winner_score = storage.winner_score.get_current_value();
        }

        winner_score 
    }

    #[public]
    fn user_score(address: AztecAddress) -> u32 {
        let score = storage.final_score.at(address).get_current_value();
        score
    }

    #[private]
    fn submit_score() {
        let capture_note = storage.capture_note.at(context.msg_sender()).get_note();
        let mut score  = storage.tally_note.at(context.msg_sender()).get_note().note.tally;
        if capture_note.note.capture_block != 0 {
            score += storage.end.read() - capture_note.note.capture_block;
        }
        CTF::at(context.this_address())
            ._submit_score(context.msg_sender(), score)
            .enqueue(&mut context);
    }

    #[public]
    #[internal]
    fn _submit_score(sender: AztecAddress, score: u32) {
        assert(context.block_number() as u32 > storage.end.read(), "Game is not over yet");

        storage.final_score.at(sender).schedule_value_change(score);
        let (winner_score, _) = storage.winner_score.get_scheduled_value();
        if(winner_score < score) {
            storage.winner_score.schedule_value_change(score);
            storage.winner.schedule_value_change(sender);
        }
    }

    #[private]
    fn tally() -> u32 {
        let note = storage.tally_note.at(context.msg_sender()).get_note();

        let event0 = TallyEvent { address: context.msg_sender(), tally: note.note.tally };

        // context.emit_event_in_private_log(
        //     event0,
        //     &mut context,
        //     context.msg_sender(),
        //     context.msg_sender(),
        //     PrivateLogContent.CONSTRAINED_ENCRYPTION,
        // );


        note.note.tally
    }

    #[public]
    fn challenge(address: AztecAddress) {
        assert(context.block_number() as u32 < storage.end.read(), "Game has ended");
        assert(context.block_number() as u32 > storage.start.read(), "Game has not started");

        let challenge_fee = storage.challenge_fee.read();
        Token::at(storage.token.read())
            .transfer_in_public(
                context.this_address(),
                context.msg_sender(),
                challenge_fee,
                0
            )
            .call(&mut context);
        storage.pot.write(storage.pot.read() + challenge_fee);

        // Ensure the game is initialized
        let challenger = storage.challenger.at(address).read();
    
        // Abort if someone has already written to this key
        assert(challenger == AztecAddress::zero(), "Challenge already exists for this address");

        let challenger = context.msg_sender();

        context.emit_public_log(
            ChallengeEvent { challenger: challenger, defender: address, block: context.block_number() }        );

        storage.challenger.at(address).write(context.msg_sender());
        storage.challenge_block.at(address).schedule_value_change(context.block_number() as u32);
    }

    #[private]
    fn slash(address: AztecAddress) {
        // Set their tally back to 0.
        let slot = storage.tally_note.at(address);
        let note = TallyNote::new(address, 0);
        slot.replace(note).emit(encode_and_encrypt_note(
            &mut context,
            address,
            context.msg_sender(),
        ));

        // Publically ack the challenge
        CTF::at(context.this_address())
            ._slash(context.msg_sender())
            .enqueue(&mut context);
    }

    #[public]
    fn _slash(address: AztecAddress) {
        let challenger = storage.challenger.at(address).read();
    
        // Abort if someone has already written to this key
        assert(challenger != AztecAddress::zero() , "Challenge is no longer open");

        storage.deposits.at(address).write(0);
        storage.pot.write(storage.pot.read() + storage.deposit_size.read());
    }

    #[private]
    fn respond(challenger: AztecAddress) {
        let responder_slot = storage.capture_note.at(context.msg_sender());
        let capture_note = responder_slot.get_note().note;
        let challenge_block = storage.challenge_block.at(context.msg_sender()).get_current_value();

        let tally_slot = storage.tally_note.at(context.msg_sender());
        let tally_note = tally_slot.get_note().note;

        // New values assuming the reponder does not have the flag 
        let mut new_tally_note = TallyNote::new(context.msg_sender(), tally_note.tally);
        let new_responder_note = CaptureNote::new(context.msg_sender(), 0);
        let mut challenger_capture_note = CaptureNote::new(challenger, 0);

        // The responder has the flag
        // Update the values accordingly
        if capture_note.capture_block != 0 {
            new_tally_note.tally = new_tally_note.tally + challenge_block - capture_note.capture_block;
            challenger_capture_note.capture_block = challenge_block;
        }

        // Emit the tally note
        tally_slot.initialize_or_replace(new_tally_note).emit(encode_and_encrypt_note(
            &mut context,
            context.msg_sender(),
            context.msg_sender(),
        ));

        // Relinquish the flag
        responder_slot.initialize_or_replace(new_responder_note).emit(encode_and_encrypt_note(
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
