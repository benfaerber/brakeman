require_relative '../test'
require 'brakeman/inline_ignore'
require 'brakeman/warning'
require 'tempfile'

class InlineIgnoreTests < Minitest::Test
  def setup
    @inline_ignore = Brakeman::InlineIgnore.new
  end

  def test_no_directives
    warning = make_warning("CheckSQL", 5, source: "User.find(params[:id])\n")

    refute @inline_ignore.ignored?(warning)
  end

  def test_same_line_directive
    source = <<~RUBY
      x = 1
      User.find(params[:id]) # brakeman:disable SQL
    RUBY

    warning = make_warning("CheckSQL", 2, source: source)

    assert @inline_ignore.ignored?(warning)
  end

  def test_preceding_line_directive
    source = <<~RUBY
      x = 1
      # brakeman:disable SQL
      User.find(params[:id])
    RUBY

    warning = make_warning("CheckSQL", 3, source: source)

    assert @inline_ignore.ignored?(warning)
  end

  def test_non_matching_check
    source = <<~RUBY
      # brakeman:disable Redirect
      User.find(params[:id])
    RUBY

    warning = make_warning("CheckSQL", 2, source: source)

    refute @inline_ignore.ignored?(warning)
  end

  def test_disable_all
    source = <<~RUBY
      # brakeman:disable all
      User.find(params[:id])
    RUBY

    warning = make_warning("CheckSQL", 2, source: source)

    assert @inline_ignore.ignored?(warning)
  end

  def test_multiple_checks
    source = <<~RUBY
      User.find(params[:id]) # brakeman:disable SQL, Redirect
    RUBY

    sql_warning = make_warning("CheckSQL", 1, source: source)
    redirect_warning = make_warning("CheckRedirect", 1, source: source)

    assert @inline_ignore.ignored?(sql_warning)
    assert @inline_ignore.ignored?(redirect_warning)
  end

  def test_directive_does_not_apply_two_lines_later
    source = <<~RUBY
      # brakeman:disable SQL
      safe_code
      User.find(params[:id])
    RUBY

    warning = make_warning("CheckSQL", 3, source: source)

    refute @inline_ignore.ignored?(warning)
  end

  def test_no_file
    warning = Brakeman::Warning.new(confidence: :high)

    refute @inline_ignore.ignored?(warning)
  end

  def test_no_line
    tracker = BrakemanTester.new_tracker
    path = tracker.app_tree.file_path("app/controllers/some_controller.rb")
    warning = Brakeman::Warning.new(file: path, confidence: :high)

    refute @inline_ignore.ignored?(warning)
  end

  def test_check_name_without_prefix
    source = <<~RUBY
      # brakeman:disable SQL
      User.find(params[:id])
    RUBY

    warning = make_warning("CheckSQL", 2, source: source)

    assert @inline_ignore.ignored?(warning)
  end

  def test_extra_whitespace_in_directive
    source = <<~RUBY
      #   brakeman:disable   SQL  ,  Redirect
      User.find(params[:id])
    RUBY

    sql_warning = make_warning("CheckSQL", 2, source: source)
    redirect_warning = make_warning("CheckRedirect", 2, source: source)

    assert @inline_ignore.ignored?(sql_warning)
    assert @inline_ignore.ignored?(redirect_warning)
  end

  def test_caches_file_parsing
    source = <<~RUBY
      # brakeman:disable SQL
      User.find(params[:id])
    RUBY

    file = create_temp_file(source)
    path = make_file_path(file.path)

    warning1 = Brakeman::Warning.new(
      confidence: :high,
      file: path,
      line: 2,
      check: "Brakeman::CheckSQL"
    )

    warning2 = Brakeman::Warning.new(
      confidence: :high,
      file: path,
      line: 2,
      check: "Brakeman::CheckSQL"
    )

    assert @inline_ignore.ignored?(warning1)
    assert @inline_ignore.ignored?(warning2)
  ensure
    file&.unlink
  end

  private

  def make_warning(check_class, line, source: "")
    file = create_temp_file(source)
    path = make_file_path(file.path)

    warning = Brakeman::Warning.new(
      confidence: :high,
      file: path,
      line: line,
      check: "Brakeman::#{check_class}"
    )

    @temp_files ||= []
    @temp_files << file

    warning
  end

  def create_temp_file(content)
    file = Tempfile.new(["brakeman_test", ".rb"])
    file.write(content)
    file.close
    file
  end

  def make_file_path(path)
    Brakeman::FilePath.new(path, path)
  end

  def teardown
    if @temp_files
      @temp_files.each(&:unlink)
    end
  end
end
