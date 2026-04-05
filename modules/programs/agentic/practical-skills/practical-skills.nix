{
  flake.modules.homeManager.practical-skills =
    let
      skills = {
        root-cause-debugging = ./_skills/root-cause-debugging;
        evidence-before-completion = ./_skills/evidence-before-completion;
        handling-review-feedback = ./_skills/handling-review-feedback;
        delegating-work = ./_skills/delegating-work;
        brainstorming = ./_skills/brainstorming;
      };
    in
    {
      programs.claude-code.skills = skills;
    };
}
