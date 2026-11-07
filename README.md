# How to use

Deriving from the concept of _skel_ folders used in Linux, I created this custom skel folder for my dotfiles. However, unlike skel folders that are just copied one-time to the user directories, I also need files to be able to sync to my GitHub repo.

So, instead of just copying the skel folders to the home dir, one can use soft links (`ln -s TARGET LINK_NAME`) so that all changes can be pooled to a single local repo and synced together to the remote repo.

