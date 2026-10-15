# frozen_string_literal: true

# Decides which questions an attendee could actually see, given their answers
# and the form's branching rules. Mirrors the panel's feedback-answers.ts, and
# is shared by submission validation and the response statistics so both agree.
class FeedbackRouting
  # questions: the form's questions (any order). continuous: single-page mode,
  # where later sections stay hidden until a branching question is answered.
  def initialize(questions, continuous: false)
    @questions = questions
    @continuous = continuous
    @pages = questions.map(&:page_number).uniq.sort
  end

  def branching_form?
    @questions.any? { |question| branching?(question) }
  end

  # answers: { question_id => answer_text }. Keys may be integers or strings.
  def reachable_questions(answers)
    return @questions if @questions.empty?

    answers = answers.transform_keys(&:to_s)
    reachable = []
    visited = []
    current_page = @pages.first

    while current_page && !visited.include?(current_page)
      visited << current_page
      page_questions = @questions.select { |q| q.page_number == current_page }
      reachable.concat(page_questions)

      break if @continuous && page_questions.any? { |q| branching?(q) && answer_for(q, answers).empty? }

      current_page = next_page(current_page, page_questions, answers)
    end

    reachable
  end

  def reachable_ids(answers)
    reachable_questions(answers).map(&:id)
  end

  private

  def branching?(question)
    question.routing_rules.is_a?(Array) && question.routing_rules.any?
  end

  def answer_for(question, answers)
    answers[question.id.to_s].to_s.strip
  end

  def matching_rule(question, answers)
    answer = answer_for(question, answers).downcase
    return if answer.empty?

    question.routing_rules.find { |r| r['answer'].to_s.strip.downcase == answer }
  end

  # Returns the next page number, or nil when the attendee goes to submit.
  def next_page(current_page, page_questions, answers)
    page_questions.select { |q| branching?(q) }.each do |q|
      rule = matching_rule(q, answers)
      next unless rule

      return nil if rule['action'] == 'submit' || rule['target_page'].blank? || rule['target_page'].to_s == 'submit'

      target = rule['target_page'].to_i
      return target if target > current_page && @pages.include?(target)
    end

    @pages.select { |p| p > current_page }.find do |candidate|
      @questions.none? { |q| unchosen_branch_target?(q, candidate, answers) }
    end
  end

  # True when the attendee answered q with a rule that leads somewhere other
  # than `candidate`, while another rule of q leads to `candidate`.
  def unchosen_branch_target?(question, candidate, answers)
    return false unless branching?(question)

    leads_to_candidate = question.routing_rules.any? do |r|
      (r['action'] == 'jump_to_page' || r['action'].blank?) && r['target_page'].to_i == candidate
    end
    return false unless leads_to_candidate

    chosen = matching_rule(question, answers)
    chosen.present? && chosen['target_page'].to_i != candidate
  end
end
