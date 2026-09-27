
1. Unfunded Reward Liability
    Description :
    Reward bertambah berdasarkan jumlah stake dan waktu yang berlalu, tetapi contract tidak memilik
    source of funding yang dapat menanggung reward yang didapatkan oleh user

    Impact :
    Contract tidak memiliki cukup Dana/Balacne untuk membayar reward yang didaptakan oleh user, 
    dan dapat memakai jumlah stake dari User, yang seharusnya tidak boleh dipakai untuk membayar reward

    Evidence :
    test_ClaimRevertsWhenRewardExceedsAvailableAssets()

    Recomendation :
    buat batsan agar contract tidak memakai total nilai dari stake user agar saat contract tidak memiliki balance yang cukup untuk membayar reward contract tidak memakai total stake user,
    dan cari source of funding yang dapat membayar reward dari user

2. Withdrawel Depends on recepient Accepting ETH 
    Description :
    jika contract penerima menolak ETH, unstake() dapat gagal karena Transfer ETH tidak berhasil

    Impact :
    penerima tidak dapat menarik nilai Stake yang di depositkan

    Evidence :
    testStakingAmountStillSameAfterUnstake()

