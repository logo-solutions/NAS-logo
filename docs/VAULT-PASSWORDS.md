# Mots de passe à ajouter au vault.yml

Exécute cette commande pour éditer le vault :

```bash
ansible-vault edit /Volumes/logousb/SSD/Projects/NAS-logo/inventory/group_vars/all/vault.yml --vault-password-file ~/.nas-logo-vault-pass
```

Ajoute ces lignes dans le vault.yml (ordre n'importe pas, mais place-les à la fin de la section des mots de passe) :

## Immich passwords

```yaml
vault_immich_loic_perso_password: ikgKokgVuxIVLiRp7GE91g
vault_immich_loic_immo_password: WzyqwhZZAl60h8ZiG-j2xw
vault_immich_loic_pro_password: aMTBaWVrkvebpqbNjPSiHQ
vault_immich_alban_password: qRBm5SKChIMiRfqRzG-DQw
vault_immich_ilan_password: S-Tm4HNGL5VQ3oV4N_jJrQ
vault_immich_mahaut_password: 6g5EYOSAd1pVnJgqdFqWzQ
vault_immich_alice_perso_password: 82tuPCniBYBS6grMgyQo3w
vault_immich_alice_prof_password: 5A2mZbc8Sg_nFg8dxtZ8iQ
```

## Paperless passwords

```yaml
vault_paperless_loic_perso_password: pCY2l6nEyO4O1UdOyJIwEw
vault_paperless_loic_immo_password: MDckhI5VJNpIwxzozTKCEg
vault_paperless_loic_pro_password: aRZnp_t_PPcE3HnfGBJj_w
vault_paperless_alban_password: cjKN55ds0OL8xHCO38aczA
vault_paperless_ilan_password: I9DLfjWhMZM3aVY38doWrA
vault_paperless_mahaut_password: rqKQP9PfbQ8A9fZGxBTpCQ
vault_paperless_alice_perso_password: cvTzufAVfjVA2zK_FVPERg
vault_paperless_alice_prof_password: D-Lqcdr3LP1Mkuf8fclj1A
```

**Après avoir édité le vault, tu pourras déployer avec :**

```bash
cd /Volumes/logousb/SSD/Projects/NAS-logo
ansible-playbook site.yml --vault-password-file ~/.nas-logo-vault-pass
```

Cela va créer tous les comptes Immich et Paperless.
