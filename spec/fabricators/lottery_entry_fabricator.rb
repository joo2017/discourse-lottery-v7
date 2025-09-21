# frozen_string_literal: true

Fabricator(:lottery_entry) do
  topic { Fabricate(:topic) }
  user { |attrs| attrs[:topic].user }
  title { sequence(:title) { |i| "Test Lottery #{i}" } }
  prize_description "Amazing prize description"
  draw_time { 1.day.from_now }
  winner_count 1
  min_participants 5
  backup_strategy "continue"
  lottery_type "random"
  status "running"
  additional_notes "Additional notes for the lottery"
end

Fabricator(:lottery_entry_with_image, from: :lottery_entry) do
  image_upload { Fabricate(:upload) }
end

Fabricator(:lottery_entry_specified, from: :lottery_entry) do
  lottery_type "specified"
  specified_floors "5,10,15"
  winner_count 3
end

Fabricator(:lottery_entry_finished, from: :lottery_entry) do
  status "finished"
  winners_data {
    [
      { user_id: 1, username: "winner1", floor: 5, post_id: 10 },
      { user_id: 2, username: "winner2", floor: 8, post_id: 15 }
    ]
  }
end

Fabricator(:lottery_entry_cancelled, from: :lottery_entry) do
  status "cancelled"
end
