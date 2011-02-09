Factory.define :child do |c|
  c.name  "John Doe"
end

Factory.define :child_with_photo, :class=>Child do |c|
  c.name  "John Doe"
  c.after_build  { |c| c.photo= uploadable_photo }
end