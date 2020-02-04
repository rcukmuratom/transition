When(/^I visit this site page$/) do
  visit site_path(@site)
end

When(/^I edit this site's transition date$/) do
  click_link 'Edit date'
  @transition_date = 1.month.from_now
  select(@transition_date.year, from: 'site_launch_date_1i')
  select(I18n.t("date.month_names")[@transition_date.month], from: 'site_launch_date_2i')
  select(@transition_date.day, from: 'site_launch_date_3i')
  click_button 'Save'
end

Then(/^I should see the new transition date$/) do
  expect(page).to have_content(@transition_date.strftime("%-d %B %Y"))
end
