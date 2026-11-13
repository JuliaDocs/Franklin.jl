<!--
reviewed: 18/10/20
-->

# Deploying your website

\blurb{Set it up once then don't think about it.}

\lineskip

\toc

\lineskip

Deploying the website is trivial on an existing web server, via GitHub or Gitlab, or on services like Netlify or deed.page.

## Deploying on an existing web server

The contents of the `__site` folder can simply be deployed to a path on an existing server as follows.
Supposing you wish your site to appear at `http://my.example.com/path/to/my/franklin/site/`.  You would take the following steps:

* Prepare the `__site` directory by running `optimize(prepath="/path/to/my/franklin/site/", minify=false)`.
Franklin.jl does not use relative links, so this step is needed to ensure that the links between site elements are correct. (The `minify = false` argument is optional but is currently recommended.)

* Copy the contents of the `__site` directory to the target location using your chosen method (for example, using [rsync](https://en.wikipedia.org/wiki/Rsync)).
 
Your site should now be live, with the index page appearing at `http://my.example.com/path/to/my/franklin/site/index.html`.

## Deploying on GitHub

### Creating a repo on GitHub

Start by creating an empty GitHub repository

@@tlist
* for a personal (or org) website the repository **must** be named `username.github.io` (or `orgname.github.io`) see also [the Github pages docs](https://pages.github.com/).
* for a project website the repo can be named anything you want, let's say `myWebsite`.
@@

\warn{
  When you consider a _project website_, you **must** define a `prepath` variable in your `config.md` with the name of that project. For instance: `@def prepath = "myWebsite"`.
  This is used upon deployment to indicate that the base URL of your website is `username.github.io/myWebsite/` instead of `username.github.io`.
  If you forget to do that, among other problems the CSS won't load and your website will look terrible 😅. 
  
  However, if you add a custom domain like `example.com` to your *project* repo like `myWebsite`, then the variable `prepath` should be set an empty string to make the CSS work.
}

@@tlist
- [This repo](https://github.com/tlienart2/tlienart2.github.io) is an example of _user website_ you can copy,
- [This repo](https://github.com/tlienart2/myWebsite) is an example of _project website_ you can copy.
@@

### Synchronise your local folder

You now just need to synchronise your repository and your local website folder; to do so, go to your terminal, `cd` to the website folder and follow the steps below:

@@tlist
- `git init && git remote add origin URL_TO_YOUR_REPO`
- `git add -A && git commit -am "initial files"`
- `git push`
@@

the GitHub action will be triggered and deploy the content of the `__site` folder to the `gh-pages` branch from which GitHub will deploy the website.

\note{It takes a couple of minutes for the whole process to complete.}

Once a green check mark appears on the GitHub repo like so:

![](/assets/img/action_check.png)

your site has finished building and the generated files are on the `gh-pages` branch.
If you see a red cross instead, click on it to see what failed, _usually_ if you manage to build your site locally, the build process should work on GitHub too.

The final step is to tell GitHub to deploy the `gh-pages` branch, for this, on the repository go to `Settings` then scroll down to `GitHub Pages` and in the `Source` dropdown, pick `gh-pages`.

Your website should now be online. To view it, on the repository page, click on `github-pages` in the right margin,

@@small-img ![](/assets/img/deployment.png)@@

then on `View deployment`.

@@small-img ![](/assets/img/deployment2.png)@@

### Examples

@@tlist
- [basic user webpage](https://github.com/tlienart2/tlienart2.github.io)
- [basic project webpage](https://github.com/tlienart2/myWebsite)
@@

### Customising the GitHub action

You might want to customise the GitHub action for instance:

@@tlist
- your website uses [`PyPlot.jl`](https://github.com/JuliaPy/PyPlot.jl) and so you need to make sure [`matplotlib`](https://matplotlib.org/) is installed,
- you want to apply some node library such as [`purgecss`](https://purgecss.com/)
- you want to disable minification or prerendering
- ...
@@

For all such operations, modify the file `.github/workflows/deploy.yml` in your site folder.
It should be fairly straightforward to see how to extend it but if you get stuck, ask on the **#franklin** slack channel.

### Migrating to the new GitHub Pages infrastructure

GitHub Pages has a whole new revamped infrastructure and workflow that does not require maintaining
an extra `gh-pages` branch. The `gh-pages`/`gh-previews` would still be required if you have PR previews
on for your project  (more about this in the "Previewing Pull Requests" section below). Read more
about how you can migrate your current infrastructure to the new format -

@@tlist
- [github pages official docs](https://docs.github.com/en/pages/setting-up-a-github-pages-site-with-jekyll/about-github-pages-and-jekyll)
- [new workflow examples](https://github.com/actions/starter-workflows/tree/main/pages)
@@

### Troubleshooting

If something failed, that you can't debug, ask on the **#franklin** slack channel explaining what's the issue and we'll try to help you out.

## Deploying on GitLab

### Creating a repo on GitLab

Start by creating an empty GitLab repository

@@tlist
* for a personal website the repository **must** be named `username.gitlab.io` see also [the Gitlab pages docs](https://about.gitlab.com/stages-devops-lifecycle/pages/),
* for a project website the repo can be named anything you want.
@@

### Create and optimize your site

As before; before pushing, call `optimize()` which will fix all your paths.

### Synchronise your local folder

Now you need to synchronise your repository and your local website folder; to do so, go to your terminal, `cd` to the website folder and follow the steps below:

@@tlist
- `git init && git remote add origin URL_TO_YOUR_REPO`
- `git add -A && git commit -am "initial files"`
@@

That's it! when you push your updates to the `master` branch, the GitLab CI will copy the `__site` folder to a virtual `public` folder and deploy its content.

\note{It takes a couple of minutes for the whole process to complete and your site to be available online.}

### Iterate

The `publish` command does the optimize followed by the git stuff all in one. So you should probably use that after the initial setup.

## Deploying on Netlify

Synchronise your local website folder with a repository (e.g. a GitHub or GitLab repository) then select that repository on Netlify and indicate you want to deploy the `__site` folder.

That's it!

## Deploying on deed.page

If you don't need a repository or CI, you can upload the built `__site` folder to [deed.page](https://deed.page), a static host that works without an account.
Leave `prepath` empty (the site is served at the root of `https://<slug>.deed.page/`), then build, pack and upload:

@@tlist
- `julia -e 'using Franklin; optimize(minify=false)'`
- `tar -C __site -czf site.tar.gz .`
- `curl -T site.tar.gz "https://deed.page/v1/sites?slug=my-franklin-site"`
@@

The JSON response contains the live URL and a `token`. Keep the token: it is shown only once and you need it to update or delete the site (send it as `Authorization: Bearer <token>` with the same `curl` command). Each upload is limited to 4 MB, see the [deed.page docs](https://deed.page/docs) for larger sites.

## Previewing Pull Requests

You can easily visualize the effect of a pull request on your website without having to serve it locally by using GitHub Pages or Netlify.
To do this you need to change a couple of things.
Assuming that you use Github Actions to deploy your website, you need to change your `deploy.yml` file to make builds from PRs.
First change:
```yml
name: Build and Deploy
on:
  push:
    branches:
      - main # or master
```
to
```yml
name: Build and Deploy
on:
  push:
    branches:
      - main # or master
  pull_request:
    branches:
      - main # or master
```
This means that each time a PR will be opened, a "preview" website will be generated and updated by the GitHub action.

Then we need to properly set up a local folder for each website generated by a PR.

### Netlify

Netlify can be used to deploy PR previews if you want to store the previews
and the original rendered website in different git branches. We use a separate
platform for previews, as GitHub allows you to deploy only one git branch at a time.

Have a look at the next (GitHub Pages) sub-section if you want to deploy both
the previews and the website on GitHub Pages.

After the `Checkout` action add the following:

```yml
- name: Fix URLs for PR preview deployment (pull request previews)
  if: github.event_name == 'pull_request'
  run: |
    echo "PREVIEW_FRANKLIN_WEBSITE_URL=https://{netlify name}.netlify.app/previews/PR${{ github.event.number }}/" >> $GITHUB_ENV
    echo "PREVIEW_FRANKLIN_PREPATH=previews/PR${{ github.event.number }}" >> $GITHUB_ENV
```
where `{netlify name}` is a name you will decide to use at the end of this explanation.
The first line keeps track of the URL where the preview will be available.
the second line only keeps track of the "prepath" of that preview URL so that it can be passed to Franklin.

Finally, we want to deploy the main website and the PR preview on different branches (and folders):
```yml
- name: Deploy (preview)
  if: github.event_name == 'pull_request' && github.repository == github.event.pull_request.head.repo.full_name # if this build is a PR build and the PR is NOT from a fork
  uses: JamesIves/github-pages-deploy-action@releases/v4
  with:
      branch: gh-preview # The branch where the PRs previews are stored
      folder: __site
      token: ${{ secrets.GITHUB_TOKEN }}
      target-folder: "previews/PR${{ github.event.number }}" # The website preview is going to be stored in a subfolder
- name: Deploy (main)
  if: github.event_name == 'push' && github.ref == 'refs/heads/dev'
  uses: JamesIves/github-pages-deploy-action@releases/v4
  with:
      token: ${{ secrets.GITHUB_TOKEN }}
      branch: gh-pages # Replace here the branch where your website is deployed
      folder: __site
```

Now to avoid problems with the subfolder structure of our website we need to make a small change to our `config.md` file.
Change the following lines
```markdown
+++
prepath     = "myprepath" # This is possibly "" for your case
website_url = "mywebsite.github.io"
+++
```
to
```markdown
+++
prepath     = get(ENV, "PREVIEW_FRANKLIN_PREPATH", "myprepath") # In the third argument put the prepath you normally use
website_url = get(ENV, "PREVIEW_FRANKLIN_WEBSITE_URL", "mywebsite.github.io") # Just put the website name
+++
```

Now for the final step, you will need to visualize the obtained previews.
Create an account on [Netlify.com](https://www.netlify.com/), add your repository and chose the `gh-preview` branch without any additional settings.
Set your Netlify website to be `{netlify name}.netlify.app`.

Once everything is set up you will be able to visualize your PR preview on `{netlify name}.netlify.app/previews/PR{number of your PR}`.

### GitHub Pages

GitHub pages can also be used to deploy PR previews, but you will need to store the
previews and the original rendered website in a single git branch. The previews will
be stored in a sub-folder inside your generated website; hence, make sure this
folder's name (the folder where previews are stored) does not conflict with an
existing folder in your website.

In the workflows below, we use a folder named "previews" to store the PR previews.

After the `Checkout` action add the following:

```yml
- name: Fix URLs for PR preview deployment (pull request previews)
  if: github.event_name == 'pull_request'
  run: | # "previews" below is the folder name where your PR previews are stored
    echo "PREVIEW_FRANKLIN_WEBSITE_URL=https://{github username}.github.io/previews/PR${{ github.event.number }}/" >> $GITHUB_ENV
    echo "PREVIEW_FRANKLIN_PREPATH=previews/PR${{ github.event.number }}" >> $GITHUB_ENV
```
where `{github username}` is your GitHub username.
The first line keeps track of the URL where the preview will be available.
the second line only keeps track of the "prepath" of that preview URL so that it can be passed to Franklin.

Finally, we want to deploy the main website and the PR preview on the same branch (but different folders):
```yml
- name: Deploy (preview)
  if: github.event_name == 'pull_request' && github.repository == github.event.pull_request.head.repo.full_name # if this build is a PR build and the PR is NOT from a fork
  uses: JamesIves/github-pages-deploy-action@releases/v4
  with:
      branch: gh-pages # The branch where your website is deployed
      folder: __site
      token: ${{ secrets.GITHUB_TOKEN }}
      target-folder: "previews/PR${{ github.event.number }}" # The website preview is going to be stored in the previews subfolder
- name: Deploy (main)
  if: github.event_name == 'push' && github.ref == 'refs/heads/dev'
  uses: JamesIves/github-pages-deploy-action@releases/v3
  with:
      token: ${{ secrets.GITHUB_TOKEN }}
      branch: gh-pages # Replace here the branch where your website is deployed
      folder: __site
      clean-exclude: |  # This makes sure that the previews are not wiped out during regular builds 
        previews/*
```

Now to avoid problems with the subfolder structure of our website we need to make a small change to our `config.md` file.
Change the following lines

```markdown
+++
prepath     = "myprepath" # This is possibly "" for your case
website_url = "mywebsite.github.io"
+++
```
to
```markdown
+++
prepath     = get(ENV, "PREVIEW_FRANKLIN_PREPATH", "myprepath") # In the third argument put the prepath you normally use
website_url = get(ENV, "PREVIEW_FRANKLIN_WEBSITE_URL", "mywebsite.github.io") # Just put the website name
+++
```

Once everything is set up you will be able to visualize your PR preview on `{github username}.github.io/previews/PR{number of your PR}`.

For a live demo of PR previews deployed using GitHub Pages, have a look at [FluxML's website](https://fluxml.ai) ([repo](https://github.com/FluxML/fluxml.github.io))!

### PR Comments

You can make things easier for your contributors to access it by adding a comment with a link to your PR automatically.
To do this add the following Github action (create a `pr_comment.yml` file in `.github/workflows/`):
```yml
name: PR Comment # Write a comment in the PR with a link to the preview of the given website
on:
  pull_request:
    types: [opened, reopened]
jobs:
  pr_comment:
    runs-on: ubuntu-latest
    steps:
      - name: Create PR comment
        if: github.event_name == 'pull_request' && github.repository == github.event.pull_request.head.repo.full_name # if this is a pull request build AND the pull request is NOT made from a fork
        uses: thollander/actions-comment-pull-request@71efef56b184328c7ef1f213577c3a90edaa4aff
        with:
          message: 'Once the build has completed, you can preview your PR at this URL: https://{netlify name}.netlify.app/previews/PR${{ github.event.number }}/'
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```
