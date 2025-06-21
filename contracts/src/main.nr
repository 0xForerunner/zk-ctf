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
        games: Vec<Game<Context>>,
    }

    struct Game<Context> {
        admin: PublicImmutable<AztecAddress, Context>,
        start: PublicImmutable<u32, Context>,
        end: PublicImmutable<u32, Context>,
        join_fee: PublicImmutable<Field, Context>,
        challenge_fee: PublicImmutable<Field, Context>,
        slash_fee: PublicImmutable<Field, Context>,
        deposit_size: PublicImmutable<Field, Context>,
        challenges: Map<AztecAddress, Challenge<Context>, Context>,
    }

    struct Challenge<Context> {
        challenger: PublicImmutable<AztecAddress, Context>,
        block: PublicImmutable<u32, Context>,
    }

    #[note]
    #[derive(Eq, Serialize, Deserialize)]
    pub struct FlagNote {
        has_flag: bool,
        tally: Field,
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

    #[private]
    fn challenge(game_id: Field, challenged: AztecAddress) {
        let game = storage.games.at(game_id);
        let bond = game.meta.read().bond;
        // …pay bond into game.pool…

        let note = ChallengeNote {
            game_id,
            challenger: context.msg_sender(),
            challenged,
            deadline_block: context.block_number() + Field::from(1),
        };
        game.challenges.insert(challenged.to_field(), note)
            .emit(encode_and_encrypt_note(&mut context,
                                        context.msg_sender(),
                                        challenged));
    }

    #[private]
    fn respond(game_id: Field) {
        let game = storage.games.at(game_id);
        let mut chal = game.challenges.at(context.msg_sender().to_field()).get_note();
        // …verify flag ownership, transfer etc…
        game.challenges.remove(context.msg_sender().to_field());
    }

}
