extends RefCounted
## Captions follow the supplied recording prompts.
const CLIPS := [
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_just_enough_to_take_the_pair.mp3",
    "event": "deal_win",
    "role": "mastermind",
    "text": "Just enough to take the pair.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_come_on_over_cards.mp3",
    "event": "deal_win",
    "role": "mastermind",
    "text": "Come on over cards.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_oh_weve_got_a_battle_brewing.mp3",
    "event": "war_start",
    "role": "mastermind",
    "text": "Oh we've got a battle brewing.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_same_rank_bigger_stakes.mp3",
    "event": "war_start",
    "role": "mastermind",
    "text": "Same rank bigger stakes.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_hold_on_theres_another_chapter.mp3",
    "event": "war_again",
    "role": "mastermind",
    "text": "Hold on there's another chapter.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_again_these_cards_are_stubborn.mp3",
    "event": "war_again",
    "role": "mastermind",
    "text": "Again these cards are stubborn.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_whew_i_can_breathe_again.mp3",
    "event": "war_win",
    "role": "mastermind",
    "text": "Whew I can breathe again.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_that_whole_pile_lovely.mp3",
    "event": "war_win",
    "role": "mastermind",
    "text": "That whole pile lovely.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_i_hope_you_brought_extra_luck.mp3",
    "event": "game_start",
    "role": "mastermind",
    "text": "I hope you brought extra luck.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_special_delivery_straight_to_me.mp3",
    "event": "heist_success",
    "role": "mastermind",
    "text": "Special delivery straight to me.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_come_meet_your_new_neighbors.mp3",
    "event": "heist_success",
    "role": "mastermind",
    "text": "Come meet your new neighbors.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_a_grand_entrance_for_my_collection.mp3",
    "event": "heist_success",
    "role": "mastermind",
    "text": "A grand entrance for my collection.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_a_little_shield_a_big_save.mp3",
    "event": "shield_block",
    "role": "mastermind",
    "text": "A little shield a big save.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_not_so_fast_card_collector.mp3",
    "event": "shield_block",
    "role": "mastermind",
    "text": "Not so fast card collector.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_everybodys_here_into_the_collection.mp3",
    "event": "set_complete",
    "role": "mastermind",
    "text": "Everybody's here into the collection.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_that_little_family_is_complete.mp3",
    "event": "set_complete",
    "role": "mastermind",
    "text": "That little family is complete.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_four_suites_one_happy_collector.mp3",
    "event": "set_complete",
    "role": "mastermind",
    "text": "Four suits one happy collector.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_victory_looks_good_in_all_four_suits.mp3",
    "event": "game_win",
    "role": "mastermind",
    "text": "Victory looks good in all four suits.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_that_was_a_game_worth_playing.mp3",
    "event": "game_complete",
    "role": "mastermind",
    "text": "That was a game worth playing.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/amara/amara_all_the_pieces_one_great_game.mp3",
    "event": "game_complete",
    "role": "mastermind",
    "text": "All the pieces one great game.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_a_little_higher_a_little_luckier.mp3",
    "event": "deal_win",
    "role": "trickster",
    "text": "A little higher a little luckier.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_up_you_go_winning_pile.mp3",
    "event": "deal_win",
    "role": "trickster",
    "text": "Up you go winning pile.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_thats_a_good_turn_of_the_cards.mp3",
    "event": "deal_win",
    "role": "trickster",
    "text": "That's a good turn of the cards.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_this_means_war.mp3",
    "event": "war_start",
    "role": "trickster",
    "text": "This means war.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_time_for_a_card_showdown.mp3",
    "event": "war_start",
    "role": "trickster",
    "text": "Time for a card showdown.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_lets_see_whats_hiding_underneath.mp3",
    "event": "war_start",
    "role": "trickster",
    "text": "Let's see whats hiding underneath.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_one_showdown_wasnt_enough.mp3",
    "event": "war_again",
    "role": "trickster",
    "text": "One showdown wasn't enough.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_the_plot_thickens_so_does_the_pile.mp3",
    "event": "war_again",
    "role": "trickster",
    "text": "The plot thickens so does the pile.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_ill_need_room_for_all_of_these.mp3",
    "event": "war_win",
    "role": "trickster",
    "text": "I'll need room for all of these.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_come_along_little_army_of_cards.mp3",
    "event": "war_win",
    "role": "trickster",
    "text": "Come along little army of cards.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_consider_that_card_relocated.mp3",
    "event": "heist_success",
    "role": "trickster",
    "text": "Consider that card relocated.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_a_tidy_little_heist.mp3",
    "event": "heist_success",
    "role": "trickster",
    "text": "A tidy little heist.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_a_little_borrowing_without_the_returning.mp3",
    "event": "heist_success",
    "role": "trickster",
    "text": "A little borrowing without the returning.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_youll_have_to_admire_it_from_there.mp3",
    "event": "shield_block",
    "role": "trickster",
    "text": "You'll have to admire it from there.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_nice_try_this_one_stays.mp3",
    "event": "shield_block",
    "role": "trickster",
    "text": "Nice try this one stays.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_no_missing_pieces_here.mp3",
    "event": "set_complete",
    "role": "trickster",
    "text": "No missing pieces here.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_one_rank_every_suit_beautiful.mp3",
    "event": "set_complete",
    "role": "trickster",
    "text": "One rank every suit beautiful.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_my_collection_takes_the_crown.mp3",
    "event": "game_win",
    "role": "trickster",
    "text": "My collection takes the crown.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_a_little_luck_a_little_heist_a_lovely_win.mp3",
    "event": "game_win",
    "role": "trickster",
    "text": "A little luck a little heist a lovely win.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/juno/juno_that_card_isnt_packed_from_there.mp3",
    "event": "shield_block",
    "role": "trickster",
    "text": "That card isn't packed for travel.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_from_the_first_flip_to_the_final_set.mp3",
    "event": "game_complete",
    "role": "boss",
    "text": "From the first flip to the final set.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_war_won_pieces_together.mp3",
    "event": "game_win",
    "role": "boss",
    "text": "War won pieces together.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_set_collected_case_closed.mp3",
    "event": "set_complete",
    "role": "boss",
    "text": "Set collected case closed.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_another_piece_of_the_puzzle.mp3",
    "event": "set_complete",
    "role": "boss",
    "text": "Another piece of the puzzle.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_all_four_together_at_last.mp3",
    "event": "set_complete",
    "role": "boss",
    "text": "All four together at last.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_still_here_still_mine.mp3",
    "event": "shield_block",
    "role": "boss",
    "text": "Still here still mine.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_heist_canceled_card_protected.mp3",
    "event": "shield_block",
    "role": "boss",
    "text": "Heist canceled card protected.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_my_shield_says_no.mp3",
    "event": "shield_block",
    "role": "boss",
    "text": "My shield says no.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_i_had_my_eye_on_that_one.mp3",
    "event": "heist_success",
    "role": "boss",
    "text": "I had my eye on that one.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_that_card_has_a_new_address.mp3",
    "event": "heist_success",
    "role": "boss",
    "text": "That card has a new address.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_that_last_card_came_through.mp3",
    "event": "war_win",
    "role": "boss",
    "text": "That last card came through.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_now_thats_a_winning_pile.mp3",
    "event": "war_win",
    "role": "boss",
    "text": "Now that's a winning pile.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_more_cards_more_suspense.mp3",
    "event": "war_again",
    "role": "boss",
    "text": "More cards more suspense.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_we_really_are_evenly_matched.mp3",
    "event": "war_again",
    "role": "boss",
    "text": "We really are evenly matched.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_yet_another_war.mp3",
    "event": "war_again",
    "role": "boss",
    "text": "Yet another war.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_ready_for_a_little_friendly_war.mp3",
    "event": "war_start",
    "role": "boss",
    "text": "Ready for a little friendly war.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_now_it_gets_interesting.mp3",
    "event": "war_start",
    "role": "boss",
    "text": "Now it gets interesting.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_a_tie_lets_settle_this.mp3",
    "event": "war_start",
    "role": "boss",
    "text": "A tie let's settle this.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_i_like_the_look_of_that_flip.mp3",
    "event": "deal_win",
    "role": "boss",
    "text": "I like the look of that flip.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/lou/lou_two_for_my_collection.mp3",
    "event": "deal_win",
    "role": "boss",
    "text": "Two for my collection.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_good_game_shall_we_shuffle_again.mp3",
    "event": "game_complete",
    "role": "pickpocket",
    "text": "Good game shall we shuffle again.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_the_cards_have_spoken_im_celebrating.mp3",
    "event": "game_win",
    "role": "pickpocket",
    "text": "The cards have spoken I'm celebrating.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_what_a_collection_what_a_finish.mp3",
    "event": "game_win",
    "role": "pickpocket",
    "text": "What a collection what a finish.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_a_perfect_quartet.mp3",
    "event": "set_complete",
    "role": "pickpocket",
    "text": "A perfect quartet.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_four_of_a_kind_safely_tucked_away.mp3",
    "event": "set_complete",
    "role": "pickpocket",
    "text": "Four of a kind safely tucked away.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_good_timing_trusty_shield.mp3",
    "event": "shield_block",
    "role": "pickpocket",
    "text": "Good timing trusty shield.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_well_that_shield_came_in_handy.mp3",
    "event": "shield_block",
    "role": "pickpocket",
    "text": "Well that shield came in handy.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_oh_youll_fit_right_in.mp3",
    "event": "heist_success",
    "role": "pickpocket",
    "text": "Oh you'll fit right in.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_one_card_closer.mp3",
    "event": "heist_success",
    "role": "pickpocket",
    "text": "One card closer.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_just_the_card_i_was_looking_for.mp3",
    "event": "heist_success",
    "role": "pickpocket",
    "text": "Just the card I was looking for.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_victory_with_a_few_extra_cards.mp3",
    "event": "war_win",
    "role": "pickpocket",
    "text": "Victory with a few extra cards.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_a_battle_worth_waiting_for.mp3",
    "event": "war_win",
    "role": "pickpocket",
    "text": "A battle worth waiting for.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_worth_the_suspense.mp3",
    "event": "war_win",
    "role": "pickpocket",
    "text": "Worth the suspense.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_that_pile_just_got_more_interesting.mp3",
    "event": "war_again",
    "role": "pickpocket",
    "text": "That pile just got more interesting.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_neither_side_is_budging.mp3",
    "event": "war_again",
    "role": "pickpocket",
    "text": "Neither side is budging.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_those_cards_arent_going_quietly.mp3",
    "event": "war_start",
    "role": "pickpocket",
    "text": "Those cards aren't going quietly.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_well_matched_shall_we.mp3",
    "event": "war_start",
    "role": "pickpocket",
    "text": "Well matched shall we.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_a_small_victory_ill_take_it.mp3",
    "event": "deal_win",
    "role": "pickpocket",
    "text": "A small victory, I'll take it.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_well_that_worked_out_nicely.mp3",
    "event": "deal_win",
    "role": "pickpocket",
    "text": "Well that worked out nicely.",
    "caption_ready": true
  },
  {
    "path": "res://games/war_and_piece/audio/voice/pip/pip_high_card_takes_it.mp3",
    "event": "deal_win",
    "role": "pickpocket",
    "text": "High card takes it.",
    "caption_ready": true
  }
]
