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
        player_flag: Map<AztecAddress, PrivateMutable<FlagNote, Context>, Context>,
        player_tally: Map<AztecAddress, PrivateMutable<TallyNote, Context>, Context>,
    }

    // #[derive(Eq, Serialize, Deserialize, Packable)]
    // struct GameMeta {
        // admin: AztecAddress,
        // start: u32,
        // end: u32,
        // join_fee: Field,
        // challenge_fee: Field,
        // slash_fee: Field,
        // deposit_size: Field,
    // }

    #[derive(Eq, Serialize, Deserialize, Packable)]
    struct Challenge {
        challenger: AztecAddress,
        block: u32,
    }

    #[note]
    #[derive(Eq, Serialize, Deserialize)]
    pub struct FlagNote {
        owner: AztecAddress,
        has_flag: bool,
    }


    impl FlagNote {
        pub fn new(owner: AztecAddress) -> Self {
            FlagNote { owner, has_flag: true }
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
        let flag_note  = FlagNote::new(context.msg_sender());
        let tally_note  = TallyNote::new(context.msg_sender());
        storage.player_flag.at(context.msg_sender()).replace(flag_note).emit(encode_and_encrypt_note(
            &mut context,
            context.msg_sender(),
            context.msg_sender(),
         ));
        storage.player_tally.at(context.msg_sender()).replace(tally_note).emit(encode_and_encrypt_note(
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
