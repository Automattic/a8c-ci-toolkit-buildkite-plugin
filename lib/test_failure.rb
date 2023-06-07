# frozen_string_literal: true

# Here's how report.junit XML files look like for failure vs success:
#
# <testcase classname='WordPressTest.MediaServiceTests' name='testDeletingLocalMediaThatDoesntExistInCoreData'>
#   <failure message='Asynchronous wait failed: Exceeded timeout of 0.1 seconds, with unfulfilled expectations: &quot;The delete call succeeds even if the media object isn&apos;t saved.&quot;.'>&lt;unknown&gt;:0</failure>
# </testcase>
# <testcase classname="tests.test_editing_drafts.TestEditingDrafts" name="test_adding_a_photo_to_text_draft">
#   <error message="failed on setup with &quot;TypeError: list indices must be integers or slices, not str&quot;">Traceback (most recent call last): ...</error>
# </testcase>
# <testcase classname='WordPressTest.MediaServiceTests' name='testDeletingLocalMediaThatDoesntExistInCoreData' time='0.145'/>
#
class TestFailure
  attr_reader :classname, :name, :message, :details
  attr_accessor :count

  def initialize(node)
    @classname = node['classname']
    @name = node['name']
    failure_node = node.elements['failure'] || node.elements['error']
    @message = failure_node['message']
    @details = failure_node.text
    @count = 1
  end

  def to_s
    times = @count > 1 ? " (#{@count} times)" : ''

    # Do not render a code block for the failure details if there are none
    formatted_details = if @details.strip.empty?
                          ''
                        else
                          <<~DETAILS

                            ```
                            #{@details}
                            ```
                          DETAILS
                        end

    <<~ENTRY
      <details><summary><tt>#{@name}</tt> in <tt>#{@classname}</tt>#{times}</summary>
      <pre>#{@message}</pre>
      #{formatted_details}
      </details>
    ENTRY
  end

  def key
    "#{@classname}.#{@name}"
  end

  def ultimately_succeeds?(parent_node:)
    all_same_test_nodes = parent_node.get_elements("testcase[@classname='#{@classname}' and @name='#{@name}']")
    # If last node found for that test doesn't have a <failure> or <error> child, then test ultimately succeeded.
    !(all_same_test_nodes.last.elements['failure'] || all_same_test_nodes.last.elements['error'])
  end

  def ==(other)
    @classname == other.classname && @name == other.name && @message == other.message && @details == other.details
  end
end
