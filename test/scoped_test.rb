require File.join(File.dirname(__FILE__), 'test_helper')

class Thing < ActiveRecord::Base
  acts_as_scoped
  belongs_to :user # don't actually have to have this
end

class Item < ActiveRecord::Base
  acts_as_scoped :user, :find_with_nil_scope => true
  belongs_to :user # don't actually have to have this
end

class Feature < ActiveRecord::Base
  acts_as_scoped :user, :find_global_nils => true
  belongs_to :user # don't actually have to have this
end

class User < ActiveRecord::Base
  cattr_accessor :current
  has_many :things
  has_many :items
  has_many :features
end

class ScopedTest < Test::Unit::TestCase
  fixtures :things, :items, :features, :users

  # This test checks the finder method if no current scope value is set
  def test_find_is_empty_without_scope
    User.current = nil
    assert_equal [], Thing.find(:all)
  end

  # This test implies count is accurate
  # also test ability to change the current scope value at run-time
  def test_scoping_count
    User.current = users(:user_1)
    assert_equal 2, Thing.find(:all).size
    assert_equal 2, Thing.count

    User.current = users(:user_2)
    assert_equal 4, Thing.find(:all).size
    assert_equal 4, Thing.count

    User.current = users(:user_3)
    assert_equal 0, Thing.find(:all).size
    assert_equal 0, Thing.count
  end

  # This test checks the actual values returned by the finder method are accurate
  # and there is no spill over between scopes
  def test_find_is_accurate_with_scope
    User.current = users(:user_1)
    assert_equal [things(:thing_1), things(:thing_2)], Thing.find(:all)

    User.current = users(:user_2)
    assert_equal [things(:thing_3), things(:thing_4), things(:thing_5), things(:thing_6)], Thing.find(:all)

    assert_equal [things(:thing_5)], Thing.find(:all, :conditions => { :name => 'Thing 1' })
    assert_equal [things(:thing_6)], Thing.find(:all, :conditions => "name = 'Thing 2'")
    assert_equal [things(:thing_5)], Thing.find(:all, :conditions => [ "name = ?", 'Thing 1' ])
    assert_equal [things(:thing_5), things(:thing_6)], Thing.find(:all, :conditions => "name LIKE 'Thing%'")
    assert_equal [things(:thing_5), things(:thing_6)], Thing.find(5,6)

    # Make sure exclusive scope works
    assert_not_equal [things(:thing_1), things(:thing_2)], Thing.find(:all, :conditions => "user_id = 1")
    assert_equal [], Thing.find(:all, :conditions => "name LIKE '%' AND user_id = 1")

    # No soup for you
    User.current = users(:user_3)
    assert_equal [], Thing.find(:all)
  end

  # Test find works
  def test_find_with_scope
    User.current = users(:user_2)
    assert_equal things(:thing_3), Thing.find(3)
  end

  # Test dynamic finder works
  def test_dynamic_finders_with_scope
    User.current = users(:user_1)
    assert_equal things(:thing_1), Thing.find_by_name('Thing 1')
  end

  # Test find doesn't find out of scope
  def test_find_with_bunk_scope
    User.current = users(:user_2)

    assert_raises(ActiveRecord::RecordNotFound) do
      Thing.find(1)
    end
  end

  # Test dynamic finder doesn't find out of scope
  def test_find_by_dynamic_with_bunk_scope
    User.current = users(:user_1)

    assert_equal 0, Thing.find_all_by_user_id(2).size
  end

  # Test create holds scope sacred
  def test_create_with_scope
    User.current = users(:user_1)
    Thing.create(:name => 'foo')

    assert_equal 3, Thing.find(:all).size
  end

  # Test destroy respects scope
  def test_destroy_with_scope
    User.current = users(:user_1)
    things(:thing_1).destroy

    assert_equal 1, Thing.find(:all).size
  end

  # Test destroy_all respects scope
  def test_destroy_all_with_scope
    User.current = users(:user_2)
    Thing.destroy_all

    assert_equal 0, Thing.find(:all).size
  end

  # Test delete respects scope
  def test_delete_with_scope
    User.current = users(:user_1)
    Thing.delete(1)

    assert_equal 1, Thing.find(:all).size
  end

  # Test delete_all respects scope
  def test_delete_all_with_scope
    User.current = users(:user_2)
    Thing.delete_all
    assert_equal 0, Thing.find(:all).size

    User.current = users(:user_1)
    assert_equal 2, Thing.find(:all).size
  end

  # This should allow us to scope user from something like account
  # enabling us to login (without having scope set) then
  # limiting our list of users by account
  def test_find_with_nil_scope
    # this should work
    User.current = nil
    assert_equal items(:item_1), Item.find_by_user_id(1)

    # this shouldn't work
    User.current = 1
    # assert_raises(ActiveRecord::RecordNotFound) do
    assert_equal [], Item.find_all_by_user_id(2)
    # end

    assert_nil Item.find_by_user_id(2)
  end

  # Should find owned by current and nil owned
  def test_find_with_global_nils
    User.current = User.find(1)
    assert_equal 3, Feature.find(:all).size
    assert_equal features(:feature_3), Feature.find_by_name('Hybrid')
  end

  # Should delete owned by current NOT nil owned
  def test_delete_with_global_nils
    User.current = User.find(1)

    assert Feature.delete_all
    assert_equal 2, Feature.find(:all).size
  end

  # Global nils should be read only
  def test_global_nils_are_readonly
    User.current = User.find(1)
    assert !Feature.find(1).readonly?
    assert Feature.find(2).readonly?
    assert Feature.find(3).readonly?
  end
end