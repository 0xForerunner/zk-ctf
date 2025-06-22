use dep::aztec::macros::aztec;

#[aztec]
pub contract CTF {
    use aztec::{
        macros::{functions::{private, public, view}, storage::{storage}},
        messages::logs::note::encode_and_encrypt_note};

    use dep::aztec::utils::comparison::{compare, Comparator};

    use dep::aztec:: macros::{
        functions::{initializer, internal }, 
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
    use std::convert::AsPrimitive;

    use aztec::oracle::random::{random, rand_oracle};   // returns a Field

/// Returns a random u32 in the range [0, n)
#[public]
fn rand_u32(n: u32) -> u32 {
    // let r: Field = random();
    let r_field: Field = rand_oracle();
    let r: u32 = r_field as u32;
    (r % n).to_u32() 
}

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
        pub fn new(owner: AztecAddress) -> Self {
            // Safety: We use the randomness to preserve the privacy of the note recipient by preventing brute-forcing,
            // so a malicious sender could use non-random values to make the note less private. But they already know
            // the full note pre-image anyway, and so the recipient already trusts them to not disclose this
            // information. We can therefore assume that the sender will cooperate in the random value generation.
            let randomness: Field = unsafe { random() };
            CaptureNote { owner, capture_block: 0, randomness }
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
        pub fn new(owner: AztecAddress) -> Self {
            // Safety: We use the randomness to preserve the privacy of the note recipient by preventing brute-forcing,
            // so a malicious sender could use non-random values to make the note less private. But they already know
            // the full note pre-image anyway, and so the recipient already trusts them to not disclose this
            // information. We can therefore assume that the sender will cooperate in the random value generation.
            let randomness: Field = unsafe { random() };

            TallyNote { owner, tally: 0 , randomness}
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

    #[initializer]
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
        storage.is_init.write(false);
        storage.num_players.write(0);
    }

    #[private]
    fn join(game_id: AztecAddress) {
        let capture_note = CaptureNote::new(context.msg_sender());
        let tally_note = TallyNote::new(context.msg_sender());
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

        CTF::at(context.this_address())
            ._join()
            .enqueue(&mut context);
    }

    #[public]
    #[internal]
    fn _join() {
        let prev = storage.num_players.read();
        storage.num_players.write(prev + 1);
    }

    #[view]
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
        if(storage.game_over.get_current_value()) {
            storage.final_score.at(sender).schedule_value_change(score);
            if(storage.winner_score.get_current_value() < score) {
                storage.winner_score.schedule_value_change(score);
                storage.winner.schedule_value_change(sender);
            }
        }
    }

    #[view]
    #[private]
    fn tally() -> u32 {
        let note = storage.tally_note.at(context.msg_sender()).get_note();
        note.note.tally
    }

    #[public]
    fn challenge(address: AztecAddress) {
        // Ensure the game is initialized
        if !storage.is_init.read() {
            
        }


        let challenger = storage.challenger.at(address).read();
    
        // Abort if someone has already written to this key
        assert(challenger != AztecAddress::zero(), "Challenge already exists for this address");

        let challenger = context.msg_sender();

        context.emit_public_log(
            ChallengeEvent { challenger: challenger, defender: address, block: context.block_number() }        );

    }

    #[public]
    fn slash(address: AztecAddress) {
        let challenger = storage.challenger.at(address).read();
    
        // Abort if someone has already written to this key
        assert(challenger == context.msg_sender(), "You are not the challenger for this address");
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
        
        let randomness: Field = unsafe { random() };
        let challenger_capture_note = CaptureNote {
            owner: challenger,
            capture_block: challenge_block,
            randomness
        };
        challenger_slot.replace(challenger_capture_note).emit(encode_and_encrypt_note(
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
